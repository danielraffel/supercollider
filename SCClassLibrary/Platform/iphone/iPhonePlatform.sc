IPhonePlatform : UnixPlatform {
	initPlatform {
		super.initPlatform;
	}

	name { ^\iphone }

	startupFiles {
		// Modern iOS: startup.scd from Documents directory
		^[this.userConfigDir +/+ "startup.scd"]
	}

	startup {
		"SuperCollider iOS Platform starting up".postln;

		// Set temp directory
		PathName.tmp_((this.userAppSupportDir +/+ "tmp/").standardizePath);

		// Configure internal server with iOS-appropriate defaults
		Server.internal.options.sampleRate = 48000;
		Server.internal.options.hardwareBufferSize = 128;
		Server.internal.options.blockSize = 64;
		Server.internal.options.numOutputBusChannels = 2;
		Server.internal.options.numInputBusChannels = 1;
		Server.internal.options.memSize = 8192;
		Server.internal.recSampleFormat = "float";
		Server.default = Server.internal;

		this.loadStartupFiles;
	}

	shutdown {
		// Clean shutdown
	}

	// iOS does not use Qt or Cocoa GUI
	defaultGUIScheme { ^\iphone }

	// iOS cannot open files with system commands
	open {|aPath|
		"iOS: cannot open external files".warn;
	}

	// iOS feature queries
	hasFeature { |feature|
		var iosFeatures = IdentitySet[\unixPipes, \cocoa, \qt, \hid];
		if (iosFeatures.includes(feature)) { ^false };
		^super.hasFeature(feature);
	}

	// Recording default format
	recHeaderFormat { ^\wav }
	recSampleFormat { ^\float }
}
