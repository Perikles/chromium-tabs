# Chromium Tabs

Chromium Tabs is a [Cocoa](http://developer.apple.com/cocoa/) framework for building applications that works like [Chromium](http://www.chromium.org/)'s window system.

- An *application* has multiple *windows*.
- Each *window* represents a unit of *tabs*.
- Each *tab* represents a stateful view.
- Each *tab* can be freely dragged between *windows*.

> **Information Regarding this Fork:**
> 
> The objectives of this fork are:
> 
> 1. Implement new features (such as Lion's fullscreen support) without moving to ARC. *[Complete]*
> 2. Add missing features. *[Complete]*
> 3. Fix memory leaks and other issues introduced from splitting the product. *[in progress]*
> 4. Adjust the project for use with MonoMac (read details below). *[Complete]*
> 5. Cleanup useless code. *[in progress]*
> 6. Reorganize project. *[in progress]*

Requirements: OS X 10.7 or later.

## Usage

The framework is distributed with an [`@rpath`](http://www.codeshorts.ca/2007/nov/01/leopard-linking-making-relocatable-libraries-movin) which means it should be embedded into your applications' Contents/Frameworks directory. In Xcode you can add a new "Copy Files" action with the "Frameworks" destination to your target.

As an alternative, with Xcode 4, you can create a new workspace which includes your project and `chromium-tabs.xcodeproj`. Once this is done, `ChromiumTabs.framework` will be available for linking like any other built-in library.

Then you need to do at least two things:

1. `#import <ChromiumTabs/ChromiumTabs.h>`
2. `[[CTBrowser browser] newWindow]` when your application has started (e.g. in the application delegates' `applicationDidFinishLaunching:`)

The example application (in `examples/simple-app/`) illustrates basic usage and likes to be inspected while you drink coffee. It looks like this:

[<img src="http://farm5.static.flickr.com/4082/4927836567_7b9f577af4_o.png" alt="A slightly boring screenshot of the example application">](http://github.com/downloads/rsms/chromium-tabs/Chromium%20Tabs.app.zip)

When building a "real" application you will need to subclass at least the `CTBrowser` class which factorises tabs and their content. The example application does this at a very basic level (provides custom tab content).

## Building

1. Check out (or download) the source code.
2. Open `chromium-tabs.xcodeproj` in [Xcode](http://developer.apple.com/tools/xcode/).
3. Choose your target and hit "Build".

There is also an optional example application in the Xcode project. You build it by selecting the "Chromium Tabs" target.

## MonoMac Bindings

The major objective of this fork is preparing the project for use with MonoMac. There are a number of forks on the original project that have seriously improved it, fixed issues, added features and reorganized it. However, all of them have also switched the project to using Automatic Reference Counting (ARC) instead of the deprecated Garbage Collection. MonoMac uses GC and the projects we wanted to use ChromiumTabs with, should support x86 (that ARC does not), so the project had to keep on using GC.

> **You can get the current MonoMac bindings for this project, here: [Amadeus.Chromium.Tabs](http://github.com/amadeusoft/amadeus-chromium-tabs).**

## Acknowledgements

Some of the code used to import features in this fork (while keeping use of GC however), comes from the following forks:

* [KOed / chromium-tabs](http://github.com/KOed/chromium-tabs)

## License

See the LICENSE file for details.
