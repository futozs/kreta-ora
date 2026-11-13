package hu.kretaora.core

import com.sun.net.httpserver.HttpServer
import hu.kretaora.core.net.HttpRequest
import hu.kretaora.core.net.OkHttpTransport
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.IOException
import java.net.InetSocketAddress
import java.util.concurrent.atomic.AtomicInteger

/** Runs the real transport against a server on the loopback interface. */
class OkHttpTransportTest {
    private val targetHits = AtomicInteger()
    private val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0).apply {
        createContext("/echo") { exchange ->
            val sent = exchange.requestBody.readBytes().toString(Charsets.UTF_8)
            val agent = exchange.requestHeaders.getFirst("User-Agent")
            val type = exchange.requestHeaders.getFirst("Content-Type")
            val answer = "${exchange.requestMethod}|$agent|$type|$sent".toByteArray()
            exchange.sendResponseHeaders(200, answer.size.toLong())
            exchange.responseBody.use { it.write(answer) }
        }
        createContext("/redirect") { exchange ->
            exchange.responseHeaders.add("Location", "/target")
            exchange.sendResponseHeaders(302, -1)
            exchange.close()
        }
        createContext("/target") { exchange ->
            targetHits.incrementAndGet()
            exchange.sendResponseHeaders(200, -1)
            exchange.close()
        }
        start()
    }
    private val base = "http://127.0.0.1:${server.address.port}"
    private val transport = OkHttpTransport()

    @AfterEach
    fun stopServer() {
        server.stop(0)
    }

    private fun send(request: HttpRequest) = runBlocking { withContext(Dispatchers.IO) { transport.send(request) } }

    @Test
    fun `sends the method, headers and form body, and returns status and body`() {
        val response = send(
            HttpRequest(
                method = "POST",
                url = "$base/echo",
                headers = mapOf(
                    "User-Agent" to KretaConfig.USER_AGENT,
                    "Content-Type" to "application/x-www-form-urlencoded",
                ),
                body = "grant_type=refresh_token",
            ),
        )
        assertEquals(200, response.status)
        assertEquals(
            "POST|${KretaConfig.USER_AGENT}|application/x-www-form-urlencoded|grant_type=refresh_token",
            response.body.toString(Charsets.UTF_8),
        )
    }

    @Test
    fun `a request without a body is a plain GET`() {
        val response = send(HttpRequest("GET", "$base/echo", mapOf("User-Agent" to "test")))
        assertEquals("GET|test|null|", response.body.toString(Charsets.UTF_8))
    }

    @Test
    fun `a redirect is returned, never followed`() {
        val response = send(HttpRequest("GET", "$base/redirect", mapOf("Authorization" to "Bearer secret")))
        assertEquals(302, response.status)
        assertEquals(0, targetHits.get())
    }

    @Test
    fun `a connection failure surfaces as an IO error`() {
        server.stop(0)
        val error = expectThrows<IOException> { send(HttpRequest("GET", "$base/echo", emptyMap())) }
        assertTrue(error.message.orEmpty().isNotEmpty())
    }
}
