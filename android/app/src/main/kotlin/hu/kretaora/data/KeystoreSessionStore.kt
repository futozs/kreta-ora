package hu.kretaora.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import hu.kretaora.core.auth.Session
import hu.kretaora.core.auth.SessionStore
import java.io.File
import java.io.IOException
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Keeps the session in a file encrypted with AES-GCM. The key lives in the
 * Android Keystore and never leaves the device, so the file is useless when
 * copied elsewhere.
 *
 * File layout: one byte with the IV length, the IV, then the ciphertext.
 */
class KeystoreSessionStore(context: Context) : SessionStore {
    private val file = AtomicFile(File(context.filesDir, "session.bin"))

    /** Null when nothing is stored, or when it can no longer be decrypted. */
    @Synchronized
    override fun load(): Session? {
        val stored = try {
            file.readFully()
        } catch (_: IOException) {
            return null
        }
        return decrypt(stored)?.let(Session::fromJson)
    }

    @Synchronized
    override fun save(session: Session) {
        val payload = try {
            encrypt(session.toJson().toByteArray(Charsets.UTF_8))
        } catch (error: GeneralSecurityException) {
            throw IOException("The session could not be encrypted", error)
        }
        val stream = file.startWrite()
        try {
            stream.write(payload)
            file.finishWrite(stream)
        } catch (error: IOException) {
            file.failWrite(stream)
            throw error
        }
    }

    @Synchronized
    override fun clear() {
        file.delete()
    }

    private fun encrypt(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val iv = cipher.iv
        return byteArrayOf(iv.size.toByte()) + iv + cipher.doFinal(plain)
    }

    private fun decrypt(stored: ByteArray): String? {
        val ivLength = stored.firstOrNull()?.toInt() ?: return null
        if (ivLength <= 0 || stored.size <= 1 + ivLength) return null
        return try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG_BITS, stored, 1, ivLength))
            String(cipher.doFinal(stored, 1 + ivLength, stored.size - 1 - ivLength), Charsets.UTF_8)
        } catch (_: GeneralSecurityException) {
            null
        }
    }

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }

        val specification = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(KEY_BITS)
            .build()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
            .apply { init(specification) }
            .generateKey()
    }

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "kretaora.session"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val KEY_BITS = 256
        const val TAG_BITS = 128
    }
}
