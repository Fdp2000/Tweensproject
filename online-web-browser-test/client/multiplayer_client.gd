extends "ws_webrtc_client.gd"

var rtc_mp := WebRTCMultiplayerPeer.new()
var sealed: bool = false

func _init() -> void:
	connected.connect(_connected)
	disconnected.connect(_disconnected)

	offer_received.connect(_offer_received)
	answer_received.connect(_answer_received)
	candidate_received.connect(_candidate_received)

	lobby_joined.connect(_lobby_joined)
	lobby_sealed.connect(_lobby_sealed)
	peer_connected.connect(_peer_connected)
	peer_disconnected.connect(_peer_disconnected)


func start(url: String, _lobby: String = "", _mesh: bool = true) -> void:
	stop()
	sealed = false
	mesh = _mesh
	lobby = _lobby
	connect_to_url(url)


func stop() -> void:
	multiplayer.multiplayer_peer = null
	rtc_mp.close()
	close()


const FORCE_TURN = false # <-- Set to false when you are done testing!

func _create_peer(id: int) -> WebRTCPeerConnection:
	var peer: WebRTCPeerConnection = WebRTCPeerConnection.new()
	# Use a public STUN server for fast P2P NAT traversal.
	# Note: STUN fails on strict NATs (cellular hotspots, enterprise firewalls).
	# The fallback TURN server is required to relay traffic when direct P2P fails.
	# Replace OpenRelay with your own Metered.ca credentials for production.
	
	var config := {
		"iceServers": [ 
			{ "urls": ["stun:stun.l.google.com:19302", "stun:stun.relay.metered.ca:80"] },
			{ 
				"urls": ["turn:standard.relay.metered.ca:80"],
				"username": "dc5a3375b81bdcfca10375c7",
				"credential": "yg8ryaAKOFsPA461"
			},
			{ 
				"urls": ["turn:standard.relay.metered.ca:80?transport=tcp"],
				"username": "dc5a3375b81bdcfca10375c7",
				"credential": "yg8ryaAKOFsPA461"
			},
			{ 
				"urls": ["turn:standard.relay.metered.ca:443"],
				"username": "dc5a3375b81bdcfca10375c7",
				"credential": "yg8ryaAKOFsPA461"
			},
			{ 
				"urls": ["turns:standard.relay.metered.ca:443?transport=tcp"],
				"username": "dc5a3375b81bdcfca10375c7",
				"credential": "yg8ryaAKOFsPA461"
			}
		]
	}
	
	if FORCE_TURN:
		config["iceTransportPolicy"] = "relay"
		
	peer.initialize(config)
	peer.session_description_created.connect(_offer_created.bind(id))
	peer.ice_candidate_created.connect(_new_ice_candidate.bind(id))
	rtc_mp.add_peer(peer, id)
	if id < rtc_mp.get_unique_id():  # So lobby creator never creates offers.
		peer.create_offer()
	return peer


func _new_ice_candidate(mid_name: String, index_name: int, sdp_name: String, id: int) -> void:
	if "typ relay" in sdp_name:
		print("📡 [WebRTC Debug] Generated TURN Relay Candidate! (Strict NAT Firewall bypassed)")
	elif "typ srflx" in sdp_name:
		print("🌐 [WebRTC Debug] Generated STUN Candidate (Direct P2P available)")
		
	send_candidate(id, mid_name, index_name, sdp_name)


func _offer_created(type: String, data: String, id: int) -> void:
	if not rtc_mp.has_peer(id):
		return
	print("created", type)
	rtc_mp.get_peer(id).connection.set_local_description(type, data)
	if type == "offer": send_offer(id, data)
	else: send_answer(id, data)


func _connected(id: int, _use_mesh: bool) -> void:
	print("Connected %d, local mesh setting: %s" % [id, mesh])
	
	# We ignore the signaling server's 'use_mesh' parameter and enforce our own!
	if mesh:
		rtc_mp.create_mesh(id)
	elif id == 1:
		rtc_mp.create_server()
	else:
		rtc_mp.create_client(id) # <--- CHANGE THIS BACK TO 'id'
	multiplayer.multiplayer_peer = rtc_mp


func _lobby_joined(_lobby: String) -> void:
	lobby = _lobby


func _lobby_sealed() -> void:
	sealed = true


func _disconnected() -> void:
	print("Disconnected: %d: %s" % [code, reason])
	if not sealed:
		stop() # Unexpected disconnect


func _peer_connected(id: int) -> void:
		# ADD THIS: If not mesh, and I am not the host, and the new peer is not the host -> Ignore!
	if not mesh and id != 1 and rtc_mp.get_unique_id() != 1: return
	print("Peer connected: %d" % id)
	_create_peer(id)


func _peer_disconnected(id: int) -> void:
	if rtc_mp.has_peer(id):
		rtc_mp.remove_peer(id)


func _offer_received(id: int, offer: String) -> void:
		# ADD THIS HERE TOO:
	if not mesh and id != 1 and rtc_mp.get_unique_id() != 1: return
	print("Got offer: %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.set_remote_description("offer", offer)


func _answer_received(id: int, answer: String) -> void:
	print("Got answer: %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.set_remote_description("answer", answer)


func _candidate_received(id: int, mid: String, index: int, sdp: String) -> void:
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.add_ice_candidate(mid, index, sdp)
