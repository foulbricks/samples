// The following functions depend on Jcrop and Iviewer Puglins to create two windows. The User is able
// to pan over the main window, zoom the image and select a part of the image that can be previewed
// over a smaller window. The user then would hit crop, to crop the image which would be croppen in the backend.

// Sets up the Image Upload Pop-up. Sets up Jcrop and Iviewer for Image Cropping Functionality
function setUpCroppingWindows() {
	
	var jcrop_api = null;
	
	// Show Upload Image Dialog Box.
	$('#add_image').bind('click', function(e){
		e.preventDefault();
		$('#upload_dialog').show().dialog();
	});
	
	// Fires When User Click on Upload Image
	$('#upload_image').bind('click', function(e){
		e.preventDefault();
		
		// Submit the Form Over An Ajax Call
		$(this).parent().ajaxSubmit({
			
			// Return If Image File Upload Field is Blank.
			beforeSubmit: function(a,f,o) {
				for(var i = 0; i < a.length; i++){
					if(a[i].name == "image[image]"){
						if(a[i].value == ""){
							return false
						}
					}
				}
				o.dataType = 'json';
			},
			complete: function(XMLHttpRequest, textStatus) {
				
				// Close Dialog Box
				$('#upload_dialog').dialog('close');
				
				// Backed Sends Text as Response, Split on '=' sign
				var res = XMLHttpRequest.responseText.split("=");
				
				// If the Request is a Success
				if(res[0] == "success") {
					
					// Hide Text of Error from Previous Attempts
					$(".flash-error").hide();
					
					// Change the Upload Image Text to 'Change Image'
					$("#add_image").text("Change Image");
					
					// Set the Preview Window with Image URL sent from server
					$(".preview-frame .preview").html("<img src='" + res[1] + "' id='preview' />");
					
					// Set up Iviewer Plugin Once. Just Load Image if one is already there.
					if($("#viewer").hasClass("iviewer_cursor")) {
						iviewer.loadImage(res[1]);
						$("[name='cropped_image[uploaded_image_path]']").val(res[2]);
					}
					else {
						
						// Set Up Jcrop. Make Sure to send callbacks to showPreview() so Preview Shows on Smaller Window
						// When the Image is Moved.
						$("#viewer").Jcrop({
							aspectRatio: 1,
							bgColor:     'transparent',
							allowSelect:		false,
							setSelect:   [225, 125, 375, 275],
							onChange: showPreview,
							onSelect: showPreview
						},function(){
							jcrop_api = this;
						});
						
						// Set a small timeout and then set the Iviewer Plugin
						setTimeout(function(){
							$("#viewer").iviewer({
								zoom: 100,
								src: res[1],
								zoom_min : 25,
								initCallback: function()
								{
									iviewer = this;
									$("[name='cropped_image[uploaded_image_path]']").val(res[2]);
								},
								onCoordsChange: function(x, y)
								{
									if(jcrop_api) {
										showPreview(jcrop_api.tellScaled(), x, y);
									}
								}
							});
						}, 200);
						
					}
					
					// Show Image Editor Section
					$("#image-editor section").show();
				}
				// If error on Ajax call, show error message sent from backend
				else {
					$("#page").html("<p class='flash-error'>" + res[1] + "</p>");
				}
			}
		});
	});
}

// Calculates The Preview shown atop of the Image Cropping Tool
// LeftOffset/Topoffset: X and Y coordinates from top point where the image is selected
// with relation of the topmost and leftmost point on Main Image Window.
function showPreview(coords, leftOffset, topOffset)
{
	// Calculate CSS positioning of the Main Image Window if not provided by Jcrop (on Initialize)
	if((typeof leftOffset != "undefined") && (typeof topOffset != "undefined")){
		var imgLeft = leftOffset;
		var imgTop = topOffset;
	}
	else {
		var imgLeft = parseInt($("#viewer img").css("left"));
		var imgTop = parseInt($("#viewer img").css("top"));
	}
	
	// Divide coordinates by width and height of preview window in pixels
	// (Aspect Ratio of Main Image Compared to Preview Image)
	var rx = 180 / coords.w;
	var ry = 180 / coords.h;
	
	marLeft = (Math.round(rx * (coords.x - imgLeft)) * -1) + "px";
	marTop = (Math.round(ry * (coords.y - imgTop)) * -1) + "px";

	var width = $("#viewer img").width();
	var height = $("#viewer img").height();

	// Set up Preview Window so it shows where image has been selected on Main Window.
	$('#preview').css({
		width: Math.round(rx * (width)) + 'px',
		height: Math.round(ry * (height)) + 'px',
		marginLeft: marLeft,
		marginTop: marTop
	});
	
	// Set Up Cropping Form with Coordinates to Crop
	$("[name='cropped_image[x]']").val(Math.round(coords.x - imgLeft));
	$("[name='cropped_image[y]']").val(Math.round(coords.y - imgTop));
	$("[name='cropped_image[w]']").val(Math.round(width));
	$("[name='cropped_image[h]']").val(Math.round(height));
	$("[name='cropped_image[cw]']").val(Math.round(coords.w));
	$("[name='cropped_image[ch]']").val(Math.round(coords.h));
}