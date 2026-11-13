package hu.kretaora.core

import hu.kretaora.core.auth.Account
import hu.kretaora.core.auth.Session
import hu.kretaora.core.auth.TokenSet
import hu.kretaora.core.model.Lesson
import hu.kretaora.core.net.HttpRequest
import hu.kretaora.core.net.HttpResponse
import hu.kretaora.core.net.HttpTransport
import hu.kretaora.core.timetable.TimetableSnapshot
import org.junit.jupiter.api.Assertions.fail
import java.net.URI
import java.net.URLDecoder
import java.nio.file.Files
import java.time.Instant
import java.time.ZonedDateTime
import java.util.Base64

/** Scripted network. Each test decides what every request gets back. */
class FakeTransport(
    /** Receives the request and how many requests came before it. */
    private val handler: (HttpRequest, Int) -> HttpResponse,
) : HttpTransport {
    private val recorded = mutableListOf<HttpRequest>()

    val requests: List<HttpRequest> get() = synchronized(recorded) { recorded.toList() }

    override suspend fun send(request: HttpRequest): HttpResponse {
        val position = synchronized(recorded) {
            recorded.add(request)
            recorded.size - 1
        }
        return handler(request, position)
    }
}

fun json(text: String, status: Int = 200) = HttpResponse(status, text.toByteArray(Charsets.UTF_8))

val HttpRequest.isTokenRequest: Boolean get() = URI(url).path.endsWith("/connect/token")

val HttpRequest.form: Map<String, String>
    get() = body.orEmpty().split("&").filter { it.isNotEmpty() }.associate { pair ->
        val (name, value) = pair.split("=", limit = 2) + ""
        URLDecoder.decode(name, Charsets.UTF_8) to URLDecoder.decode(value, Charsets.UTF_8)
    }

/** Fails unless the block throws exactly the expected kind of error. */
inline fun <reified T : Throwable> expectThrows(block: () -> Unit): T {
    try {
        block()
    } catch (error: Throwable) {
        if (error is T) return error
        throw error
    }
    return fail("Expected ${T::class.simpleName}, but nothing was thrown")
}

object Fixture {
    /** Monday 2026-11-16, a school week. Times below are school time. */
    fun date(day: Int, hour: Int = 0, minute: Int = 0): Instant =
        ZonedDateTime.of(2026, 11, day, hour, minute, 0, 0, KretaConfig.ZONE).toInstant()

    fun lesson(
        id: String,
        day: Int,
        index: Int,
        name: String = "matematika",
        teacher: String? = "Kiss Béla",
        substitute: String? = null,
        room: String? = "12",
        cancelled: Boolean = false,
        kind: Lesson.Kind = Lesson.Kind.LESSON,
        topic: String? = null,
    ): Lesson {
        // 1st lesson 8:00, then one every 55 minutes, 45 minutes long.
        val start = date(day, 8, 0).plusSeconds((index - 1) * 55L * 60)
        return Lesson(
            id = id,
            start = start,
            end = start.plusSeconds(45L * 60),
            name = name,
            index = index,
            teacher = teacher,
            substituteTeacher = substitute,
            room = room,
            topic = topic,
            kind = kind,
            isCancelled = cancelled,
        )
    }

    /** A snapshot covering the two weeks starting Monday the 16th. */
    fun snapshot(
        lessons: List<Lesson>,
        account: String = "account",
        from: Int = 16,
        to: Int = 30,
    ) = TimetableSnapshot(
        accountId = account,
        lessons = lessons,
        rangeStart = date(from),
        rangeEnd = date(to),
        syncedAt = date(from),
    )

    /** `claims` is the JSON text of the token payload. */
    fun jwt(claims: String): String {
        fun encode(text: String) = Base64.getUrlEncoder().withoutPadding().encodeToString(text.toByteArray())
        return "${encode("""{"alg":"RS256"}""")}.${encode(claims)}.signature"
    }

    fun tokenJson(
        access: String = "access-1",
        refresh: String? = "refresh-1",
        idToken: String? = null,
        expiresIn: String = "1800",
    ): String = listOfNotNull(
        """"access_token":"$access"""",
        refresh?.let { """"refresh_token":"$it"""" },
        idToken?.let { """"id_token":"$it"""" },
        """"expires_in":$expiresIn""",
    ).joinToString(",", prefix = "{", postfix = "}")

    val account = Account(
        id = "account",
        institutionCode = "school-a",
        userName = "72345678901",
        displayName = "Teszt Elek",
    )

    fun session(expiresAt: Instant, access: String = "access-0", refresh: String = "refresh-0") =
        Session(account, TokenSet(access, refresh, expiresAt))

    /** Shaped like a real `OrarendElemek` row. */
    fun lessonJson(
        uid: String = "101,TanitasiOra,2026-11-16T07:00:00Z",
        start: String = "2026-11-16T07:00:00Z",
        end: String = "2026-11-16T07:45:00Z",
        state: String = "Naplozott",
        type: String = "TanitasiOra",
        substitute: String = "null",
    ): String = """
        {
          "Uid": "$uid",
          "Datum": "2026-11-15T23:00:00Z",
          "KezdetIdopont": "$start",
          "VegIdopont": "$end",
          "Nev": "matematika",
          "Oraszam": 1,
          "OraEvesSorszama": 42,
          "OsztalyCsoport": {"Uid": "837", "Nev": "10.A"},
          "TanarNeve": "Kiss Béla",
          "Tantargy": {"Uid": "368", "Nev": "matematika", "Kategoria": {"Uid": "1", "Nev": "matematika"}},
          "Tema": " ",
          "TeremNeve": "12",
          "Tipus": {"Uid": "2,TanitasiOra", "Nev": "$type", "Leiras": "Tanítási óra"},
          "Allapot": {"Uid": "1,$state", "Nev": "$state", "Leiras": "$state"},
          "HelyettesTanarNeve": $substitute,
          "HaziFeladatUid": null,
          "BejelentettSzamonkeresUid": "5512",
          "IsDigitalisOra": false
        }
    """.trimIndent()
}

fun temporaryDirectory() = Files.createTempDirectory("kretaora-core").toFile()
