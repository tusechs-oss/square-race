extends Node

func load_texture_from_buffer(body: PackedByteArray) -> ImageTexture:
	var img = Image.new()
	var err = OK
	
	# Kiểm tra header của file (Magic bytes)
	if body.slice(0, 4) == PackedByteArray([137, 80, 78, 71]):
		err = img.load_png_from_buffer(body)
	elif body.slice(0, 3) == PackedByteArray([255, 216, 255]):
		err = img.load_jpg_from_buffer(body)
	else:
		err = img.load_webp_from_buffer(body)
		
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null
