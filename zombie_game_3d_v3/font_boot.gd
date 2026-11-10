extends Node
# Автозавантаження: на старті гри ставить основний шрифт (game_fonts.gd) для всього тексту — і в меню, і в бою.

const GameFonts = preload("res://game_fonts.gd")

func _enter_tree() -> void:
    GameFonts.install_global()
