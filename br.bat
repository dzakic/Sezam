msbuild /p:configuraiont=release /t:clean,rebuild

pushd Bin\Release
7z a ..\..\NVS Sezam.*.dll Sezam.*.exe
popd

copy NVS.7z \\mi\Main\opt\debian\usr\share\sezam\update