.PHONY: app run install dmg clean

app:
	bash scripts/build_app.sh

dmg:
	bash scripts/make_dmg.sh

run: app
	open build/Murmur.app

install: app
	rm -rf /Applications/Murmur.app
	cp -r build/Murmur.app /Applications/
	@echo "Installed to /Applications/Murmur.app"

clean:
	rm -rf .build build
