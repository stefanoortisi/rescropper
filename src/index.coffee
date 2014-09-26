path 			= require( 'path' );
fs      		= require( 'fs' );
argv  			= require( 'minimist' )( process.argv.slice(2));
happens 		= require 'happens'
easyimg  		= require 'easyimage'

module.exports = class ImageResizer

	config: null

	constructor: ( ) ->
		@events = happens()


	resize: ( config ) ->

		config_path = path.join( process.cwd(), config.c)

		@config = require config_path


		# Normalize config paths
		dir = @get_dir_from_filepath config.c

		@normalize_folder @config, 'source', dir
		@normalize_folder @config, 'dest_resized', dir
		@normalize_folder @config, 'dest_cropped', dir


		# Get the files from the source
		@raw = @get_files_from_dir @config.source

		console.log "###############"
		console.log "Images to resize and crop: " + @raw.length
		console.log "###############"
		@counter = 0

		@next_tick()

	next_tick: ( ) =>
		if @counter < @raw.length

			image = @raw[ @counter++ ]

			console.log "Image #" + @counter + " - " + image

			easyimg.info( image ).then (file) =>
				w = file.width
				h = file.height
				# step 1: Resize the image
				@resize_img image, w, h, =>
					# step 2: Crop the image
					@crop_image image, w, h, @next_tick


			, (err) ->
				console.log 'error', err
				
		else
			console.log "Resize completed {" + @config.width_resized + "} - Crop completed {" + @config.width_cropped + "}"

		

	resize_img: ( image, w, h, callback ) =>
		
		dest_file = @config.dest_resized + "/" + path.basename( image )

		# Remove the file if it exists
		if fs.existsSync dest_file
			fs.unlinkSync dest_file

		data = 
			src: image
			width: @config.width_resized
			height: @config.width_resized * h / w
			dst: dest_file
			quality: 75
		
		easyimg.resize( data ).then (file) ->
			callback()
		, (err) ->
			console.log "Error resizing", err
			callback()


	crop_image: ( image, w, h, callback ) =>

		
		dest_file = @config.dest_cropped + "/" + path.basename( image )

		# Remove the file if it exists
		if fs.existsSync dest_file
			fs.unlinkSync dest_file

		if w > h
			res_height = @config.width_cropped
			res_width = res_height * w / h

		else
			res_width = @config.width_cropped
			res_height = res_width * h / w


		original_size = Math.min w, h
		easyimg.rescrop(
			src 		: image
			dst 		: dest_file,
			width 		: res_width, 
			height 		: res_height,
			cropwidth 	: @config.width_cropped, 
			cropheight 	: @config.width_cropped,
			x 			:0, 
			y 			:0
		).then (image) =>
			callback()
		, (err) =>
			console.log(err);
			callback()


	get_files_from_dir: ( dir ) ->
		unless fs.existsSync dir
			@error "Directory #{dir} doesn't exist."
			return []

		files = fs.readdirSync dir

		output = [];
		for item in files

			if item[ 0 ] != '.' and path.extname( item ) in [ '.jpg', '.png', '.jpeg' ]
				output.push( path.join dir, item )

		return output

	get_dir_from_filepath: ( filepath ) ->
		temp = filepath.split "/"
		temp.length--
		return temp.join '/'

	normalize_folder: ( obj, prop, relative_path ) ->
		obj[ prop ] = path.join relative_path, obj[ prop ]

		# Check if the destination directory exists
		unless fs.existsSync obj[ prop ]
			fs.mkdirSync obj[ prop ]


	error: ( message ) ->
		console.error message
		@events.emit "error", message
