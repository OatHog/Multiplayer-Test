extends Node

@onready var main_menu = $"../CanvasLayer/Main Menu"
@onready var name_entry = $"../CanvasLayer/Main Menu/NameEntry"
@onready var address_entry = $"../CanvasLayer/Main Menu/AddressEntry"
@onready var host_label =  $"../CanvasLayer/Main Menu/HostLabel"
@onready var address_warning_label = $"../CanvasLayer/Main Menu/AddressWarningLabel"
@onready var name_warning_label = $"../CanvasLayer/Main Menu/NameWarningLabel"

@onready var character_select = $"../CanvasLayer/CharacterSelect"
@onready var helmet_button = $"../CanvasLayer/CharacterSelect/Helmet/HelmetButton"
@onready var gunslinger_button = $"../CanvasLayer/CharacterSelect/Gunslinger/GunslingerButton"
@onready var start_button = $"../CanvasLayer/CharacterSelect/StartButton"

@onready var platform = $"../Platform"

# Multiplayer related variables
const helmet = preload("res://Scenes/Characters/helmet.tscn")
const gunslinger = preload("res://Scenes/Characters/gunslinger.tscn")
const PORT = 6000
@onready var enet_peer = ENetMultiplayerPeer.new()

func _ready():
	main_menu.show()
	platform.hide()
	host_label.hide()
	address_warning_label.hide()
	name_warning_label.hide()
	character_select.hide()

func _input(event):
	if event.is_action_pressed("v"):
		print(GameManager.players)

@rpc("any_peer")
func send_player_information(name: String, id: int, character: String):
	if !GameManager.players.has(id):
		GameManager.players[id] = {
			"name" : name,
			"id" : id,
			"character" : character
		}
	if multiplayer.is_server():
		for i in GameManager.players:
			send_player_information.rpc(GameManager.players[i].name, i, character)

func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)
	
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")
		
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)
		
	print("Success! Join Address: %s" % upnp.query_external_address())

func connected_to_server():
	send_player_information.rpc_id(1, name_entry.text, multiplayer.get_unique_id(), "Helmet")

func _on_host_pressed():
	enet_peer.create_server(PORT, 5)
	multiplayer.multiplayer_peer = enet_peer
	
	upnp_setup()
	
	send_player_information(name_entry.text, multiplayer.get_unique_id(), "")
	
	host_label.text = "Hosting. Waiting for players..."
	host_label.show()

@rpc("any_peer", "call_local")
func _on_join_pressed():
	if (address_entry.text != "") and (name_entry.text != ""):
		enet_peer.create_client(address_entry.text, PORT)
		multiplayer.multiplayer_peer = enet_peer
		
		var id = multiplayer.get_unique_id()
		multiplayer.connected_to_server.connect(connected_to_server)
		host_label.text = "Joined. Waiting for host to start..."
		host_label.show()
	
	if (address_entry.text == ""):
		address_warning_label.text = "Enter an IP address."
		address_warning_label.show()
		
		var timer = get_tree().create_timer(5)
		await timer.timeout
		address_warning_label.hide()
	
	if (name_entry.text == ""):
		name_warning_label.text = "Please enter a username."
		name_warning_label.show()
		
		var timer = get_tree().create_timer(5)
		await timer.timeout
		address_warning_label.hide()

func server_connection_failed():
	print("connection failed.")

func _on_proceed_pressed():
	start_lobby.rpc()

@rpc("any_peer", "call_local")
func start_lobby():
	main_menu.hide()
	character_select.show()

# Handle character select
@rpc("any_peer", "call_local")
func add_character(peer_id: int, character: String):
	if GameManager.players[peer_id].character == "Helmet":
		var helmet = helmet.instantiate()
		helmet.name = str(peer_id)
		add_child(helmet)
		helmet.global_position = $"../Platform/SpawnPoint".global_position
	
	if GameManager.players[peer_id].character == "Gunslinger":
		var gunslinger = gunslinger.instantiate()
		gunslinger.name = str(peer_id)
		add_child(gunslinger)
		gunslinger.global_position = $"../Platform/SpawnPoint".global_position

@rpc("any_peer", "call_local")
func send_helmet_type():
	GameManager.players[multiplayer.get_unique_id()].character = "Helmet"

@rpc("any_peer", "call_local")
func send_gunslinger_type(peer_id):
	GameManager.players[peer_id].character = "Gunslinger"

@rpc("any_peer", "call_local")
func _on_helmet_button_pressed():
	send_helmet_type.rpc()
	print(GameManager.players)
	helmet_button.disabled = true
	gunslinger_button.disabled = false

@rpc("any_peer", "call_local")
func _on_gunslinger_button_pressed():
	var peer_id = multiplayer.get_unique_id()
	send_gunslinger_type.rpc(peer_id)
	print(GameManager.players)
	gunslinger_button.disabled = true
	helmet_button.disabled = false

@rpc("any_peer", "call_local")
func _on_start_button_pressed():
	var peer_id = multiplayer.get_unique_id()
	add_character.rpc(peer_id, GameManager.players[peer_id].character)
	character_select.hide()
	platform.show()
