package hu.kretaora.core.net

import hu.kretaora.core.KretaConfig
import hu.kretaora.core.KretaException
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okio.Buffer
import java.io.IOException
import java.time.Duration
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class HttpRequest(
    val method: String,
    val url: String,
    val headers: Map<String, String>,
    /** A form-encoded body, or null for a request without one. */
    val body: String? = null,
)

class HttpResponse(val status: Int, val body: ByteArray)

/** The only seam to the network, so everything above it is testable offline. */
interface HttpTransport {
    suspend fun send(request: HttpRequest): HttpResponse
}

/**
 * Production transport: no cookies, no cache, bounded timeouts, and no
 * redirect following, so a redirect can never forward a bearer token.
 */
class OkHttpTransport(private val client: OkHttpClient = defaultClient()) : HttpTransport {
    override suspend fun send(request: HttpRequest): HttpResponse =
        suspendCancellableCoroutine { continuation ->
            val call = client.newCall(request.toOkHttp())
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    continuation.resumeWithException(e)
                }

                override fun onResponse(call: Call, response: Response) {
                    try {
                        val result = response.use { HttpResponse(it.code, readBounded(it)) }
                        continuation.resume(result)
                    } catch (e: IOException) {
                        continuation.resumeWithException(e)
                    } catch (e: KretaException) {
                        continuation.resumeWithException(e)
                    }
                }
            })
        }

    private fun HttpRequest.toOkHttp(): Request {
        val builder = Request.Builder().url(url)
        headers.forEach { (name, value) -> builder.header(name, value) }
        builder.method(method, body?.toByteArray(Charsets.UTF_8)?.toRequestBody())
        return builder.build()
    }

    /** Reads the body, giving up once it is larger than any real answer. */
    private fun readBounded(response: Response): ByteArray {
        val source = response.body.source()
        val buffer = Buffer()
        while (buffer.size <= KretaConfig.MAX_RESPONSE_BYTES) {
            if (source.read(buffer, READ_CHUNK_BYTES) == -1L) return buffer.readByteArray()
        }
        throw KretaException.BadResponse()
    }

    private companion object {
        const val READ_CHUNK_BYTES = 8192L

        fun defaultClient(): OkHttpClient =
            OkHttpClient.Builder()
                .followRedirects(false)
                .followSslRedirects(false)
                .connectTimeout(Duration.ofSeconds(10))
                .readTimeout(Duration.ofSeconds(25))
                .callTimeout(Duration.ofSeconds(40))
                .build()
    }
}
