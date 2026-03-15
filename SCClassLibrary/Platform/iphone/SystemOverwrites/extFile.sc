// iOS sandbox file operations
// The app has access to its own Documents, tmp, and Library directories.
// boost::filesystem works within the app sandbox on modern iOS.

+ File {
	*exists { arg pathName;
		// Use standard implementation — boost::filesystem works in iOS sandbox
		_FileExists
		^this.primitiveFailed
	}
}
