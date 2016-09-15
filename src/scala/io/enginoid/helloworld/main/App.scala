package io.enginoid.helloworld.main

import io.finch._
import com.twitter.finagle.Http
import com.twitter.util.Await

object HttpApp extends App {
  val api = get("hello") { Ok("Hello, World!") }
  val server = Http.server.serve(":8080", api.toServiceAs[Text.Plain])
  Await.ready(server)
}
