PROJECTS = Telnet Web

.PHONY: run clean

run-telnet:
	cd Telnet && dotnet run

# Bind to all interfaces (IPv4 + IPv6). Override to change address/port,
# e.g. make run-web WEB_URL='http://[::]:5000' or WEB_URL='http://0.0.0.0:5000'.
WEB_URL ?= http://*:5000

run-web:
	cd Web && ASPNETCORE_URLS=$(WEB_URL) dotnet run --urls $(WEB_URL)

clean:
	rm -rf bin obj
