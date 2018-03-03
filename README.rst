ixnetwork.rb is the Ruby library for the IxNetwork Low Level API that allows you to configure and run IxNetwork tests.

Installing
==========
| The master branch always contains the latest official release. It is only updated on new IxNetwork releases. Official releases are posted to `RubyGems <http://rubygems.org/gems/ixnetwork>`_.
| The dev branch contains improvements and fixes of the current release that will go into the next release version.


 * To install the official release just ``run gem install ixnetwork``
 * To install the version in github: clone the repository, run ``gem build ixnetwork.gemspec`` and then ``gem install ./ixnetwork-8.40.0.gem``.
 * To just use the library in github without building and installing add the path to the library to   Ruby's $LOAD_PATH

Documentation
=============
| For general language documentation of IxNetwork API see `IxNetwork API Docs <http://downloads.ixiacom.com/library/user_guides/IxNetwork/8.40/EA_8.40_Rev_A/LowLevelApiGuide.zip>`_.
| This will require a login to `Ixia Support <https://support.ixiacom.com/user-guide>`_ web page.


IxNetwork API server / Ruby Support
==================================
ixnetwork API lib 8.40.0 supports IxNetwork API server 8.40+ and Ruby 1.9.3.

Compatibility Policy
====================
| ixnetwork supported IxNetwork API server version and Ruby versions are mentioned in the above "Support" section.
| Compatibility with older versions may work but will not be actively supported.

Related Projects
================
* IxNetwork API Tcl Bindings: https://github.com/ixiacom/ixnetwork-api-tcl
* IxNetwork API Python Bindings: https://github.com/ixiacom/ixnetwork-api-py
* IxNetwork API Ruby Bindings: https://github.com/ixiacom/ixnetwork-api-rb
