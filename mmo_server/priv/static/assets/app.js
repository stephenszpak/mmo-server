// Phoenix ships compiled JavaScript that exposes `Phoenix` and `LiveView`
// objects on the global `window`. These provide the `Socket` and
// `LiveSocket` constructors. Since the static assets are served directly
// without a bundler, we use the globals instead of ES module imports.
let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content")
let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  params: {_csrf_token: csrfToken}
})
liveSocket.connect()

window.liveSocket = liveSocket
