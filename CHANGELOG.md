# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2018-02-12

### Changed

* Updating to `ecto` verion 2.2

## [1.0.0] - 2018-01-31

### Changed

* Upping version of `mssqlex` to 1.0.0, thus allowing the following change:
  * Changed the default version of the ODBC Driver to 17. This is to reflect what version is installed when running apt-get install msodbcsql on Debian Jessie. It may cause breaking changes for some users who rely on the default being 13.

## [0.3.0] - 2017-07-21

### Added

* Upping version of `mssqlex` to 0.8.0, thus allowing the named instance option.

## [0.2.0] - 2017-07-06

### Added

* Upping version of `mssqlex` to 0.7.0 thus allowing custom ports.
