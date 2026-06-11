-- Arranges the Murmur DMG Finder window: icon view, background, positions.
tell application "Finder"
	tell disk "Murmur"
		open
		set current view of container window to icon view
		set toolbar visible of container window to false
		set statusbar visible of container window to false
		set the bounds of container window to {200, 120, 860, 520}
		set viewOptions to the icon view options of container window
		set arrangement of viewOptions to not arranged
		set icon size of viewOptions to 100
		set text size of viewOptions to 13
		set background picture of viewOptions to file ".background:bg.tiff"
		set position of item "Murmur.app" of container window to {165, 195}
		set position of item "Applications" of container window to {495, 195}
		update without registering applications
		delay 1
		close
	end tell
end tell
