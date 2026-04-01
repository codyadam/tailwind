extends Node

func is_dedicated_server() -> bool:
    return DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server")