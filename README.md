
# TextWrapper
A module to wrap text text into multiple lines as they'd normally be in textlabels.

# Features
* Very fast and caches previous results to accelerate future runs
* Supports richtext
* Can return offsets of characters provided in `CharactersToFind` array as Vector2's

# API
### TextWrapper.WrapText(TextSource, CharactersToFind) -> WrapTextResult
Takes a textlabel or a table containing info about the text and its frame, and returns a table which contains:
- Width: number - Width of all text
- Height: number - Height of all text
- Lines: {Lineinfo} - Array containing Width, Height, and Content of each line.
- CharacterOffsets: {vector}? - Array containing vector offset of each character position provided in `CharactersToFind`, original order of the array is preserved and positions past string length are discarded. **Z** component of the vector is height of the line the character is in.

If you provide CharactersToFind, it should be an array containing **character positions**.
> [!WARNING]
> CharacterOffsets currently doesn't support textalignment, and assumes that your text is aligned to top and left.

### TextWrapper.ResetCache() -> ()
Resets font character cache that is used to accelerate **WrapText**()

# License
TextWrapper is licensed under the [MIT](LICENSE).