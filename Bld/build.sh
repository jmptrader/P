#!/bin/bash

SCRIPT=$0
SCRIPTPATH=$(dirname "$SCRIPT") #Absolute path of script
pushd $SCRIPTPATH
cd ..

export MONO_IOMAP=case

echo ============= Building P SDK ===============

type xbuild >/dev/null 2>&1 || { echo >&2 "xbuild is not installed. Exiting..."; popd; exit 1; }

Configuration=Debug
Platform=x86
if [ $# -ne 2 ]; then
    echo "No configuration supplied. Falling back on default: Debug,x86"
else
    Configuration=$1
    Configuration="$(tr '[:lower:]' '[:upper:]' <<< ${Configuration:0:1})${Configuration:1}"
    Platform=$2
fi

echo Configuration is $Configuration, $Platform

git submodule update --init --recursive --remote

mono Bld/nuget.exe restore P.sln

cd Ext/Zing

echo xbuild Zing.sln /p:Platform=$Platform /p:Configuration=$Configuration
xbuild ZING.sln /p:Platform=$Platform /p:Configuration=$Configuration

if [ $? -ne  0 ]; then
    echo "Zing build failed. Exiting..."
    popd
    exit 2
fi

BinaryDrop=../../Bld/Drops/$Configuration/$Platform/Binaries

if [ ! -f $BinaryDrop ]; then
    mkdir -p $BinaryDrop
fi

filesToCopy="zc/bin/$Platform/$Configuration/zc.exe
             ZingExplorer/bin/$Platform/$Configuration/ZingExplorer.dll
             Zinger/bin/$Platform/$Configuration/Zinger.exe
             Microsoft.Zing/bin/$Platform/$Configuration/Microsoft.Zing.dll
             Microsoft.Zing.Runtime/bin/$Platform/$Configuration/Microsoft.Zing.Runtime.dll
             Microsoft.Zing/bin/$Platform/$Configuration/Microsoft.Comega.dll
             Microsoft.Zing/bin/$Platform/$Configuration/Microsoft.Comega.Runtime.dll
             Resources/external/CCI/System.Compiler.dll
             Resources/external/CCI/System.Compiler.Framework.dll
             Resources/external/CCI/System.Compiler.Runtime.dll
             DelayingSchedulers/CustomDelayingScheduler/bin/$Platform/$Configuration/CustomDelayingScheduler.dll
             DelayingSchedulers/RandomDelayingScheduler/bin/$Platform/$Configuration/RandomDelayingScheduler.dll
             DelayingSchedulers/RoundRobinDelayingScheduler/bin/$Platform/$Configuration/RoundRobinDelayingScheduler.dll
             DelayingSchedulers/RunToCompletionDelayingScheduler/bin/$Platform/$Configuration/RunToCompletionDelayingScheduler.dll" 

for i in $filesToCopy
do
    cp $i $BinaryDrop
done

cd ../..

# This code fixes a problem in MIDL compile by forcing recompile of these files for each configuration.
rm Src/PrtDist/Core/NodeManager_c.c
rm Src/PrtDist/Core/NodeManager_s.c

echo xbuild ext/Formula/src/Extensions/FormulaCodeGeneratorTask/FormulaCodeGeneratorTask.csproj /p:Platform=$Platform /p:Configuration=$Configuration
xbuild ext/Formula/src/Extensions/FormulaCodeGeneratorTask/FormulaCodeGeneratorTask.csproj /p:Platform=$Platform /p:Configuration=$Configuration

echo xbuild P.sln /p:Platform=$Platform /p:Configuration=$Configuration
xbuild  P.sln /p:Platform=$Platform /p:Configuration=$Configuration /t:Clean
xbuild P.sln /p:Platform=$Platform /p:Configuration=$Configuration

popd

mkdir -p build; cd build; cmake ../../Src; make


