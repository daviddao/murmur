.PHONY: app run install clean

app:
	bash scripts/build_app.sh

run: app
	open build/Murmur.app

install: app
	rm -rf /Applications/Murmur.app
	cp -r build/Murmur.app /Applications/
	@echo "Installed to /Applications/Murmur.app"

clean:
	rm -rf .build build
