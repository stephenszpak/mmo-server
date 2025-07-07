import {Socket} from "/js/phoenix.min.js"
import {LiveSocket} from "/js/phoenix_live_view.min.js"

let liveSocket = new LiveSocket("/live", Socket)
liveSocket.connect()

window.liveSocket = liveSocket
