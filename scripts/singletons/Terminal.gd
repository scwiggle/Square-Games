extends Control

const CAPITALIZED: Dictionary[String, String] = {
	"`" = "~",
	"0" = ")",
	"1" = "!",
	"2" = "@",
	"3" = "#",
	"4" = "$",
	"5" = "%",
	"6" = "^",
	"7" = "&",
	"8" = "*",
	"9" = "(",
	"-" = "_",
	"=" = "+",
	"[" = "{",
	"]" = "}",
	"\\" = "|",
	"," = "<",
	"." = ">",
	"/" = "?",
	";" = ":",
	"'" = "\"",
}

@onready var output: RichTextLabel = $"./RichTextLabel"
@onready var input: LineEdit = $"./LineEdit"

var is_accepting_input: bool = true:
	set(x):
		is_accepting_input = x
		if is_accepting_input:
			input.edit()
		else:
			input.unedit()
var console_text:String = ""

var command_history: Array[String] = []
var command_history_cursor: int = -1

signal line_entered

func print_console(txt:String) -> void:
	console_text += txt
	update_console()

func update_console() -> void:
	output.text = console_text

func _ready() -> void:
	self.get_parent().call_deferred(&"remove_child", self)
	update_console()
	print_console("Welcome to Square Games. Type \"help\" to see all commands.\n")
	input.edit()

	input.text_submitted.connect(func(text: String) -> void:
		input.text = ""
		command_history.insert(0, text)
		line_entered.emit(text)
		command_history_cursor=-1
	)

func _input(event:InputEvent) -> void:
	if not is_accepting_input:
		return
	if event.is_pressed():
		if event is InputEventKey and not event.echo:
			var keylabel: int = event.key_label
			#print(keylabel)
			match keylabel:
				KEY_UP:
					if len(command_history)==0: return
					command_history_cursor = clamp(command_history_cursor + 1, -1, len(command_history)-1)
					input.text = command_history[command_history_cursor]
					await get_tree().process_frame
					input.caret_column = input.text.length()
				KEY_DOWN:
					if len(command_history)==0: return
					command_history_cursor = clamp(command_history_cursor - 1, -1, len(command_history)-1)
					if command_history_cursor==-1:
						input.text = ""
					else:
						input.text = command_history[command_history_cursor]
						await get_tree().process_frame
						input.caret_blink = input.text.length()
				_:
					return
