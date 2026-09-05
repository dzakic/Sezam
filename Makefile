PROJECTS = Telnet Web

.PHONY: run clean

run-telnet:
	cd Telnet && dotnet run

run-web:
	cd Web && dotnet run

clean:
	rm -rf bin obj
