Dao & Norm
===
* Dao - A ColdFusion library for easy and db agnostic CRUD interaction and Linq style query building.
* Norm (Not ORM) - A dynamic Object Mapping layer built on top of DAO that provides oData support on top of ORM style object interactions (load, save, relate entities, etc...).

# Elevator Pitch
Dao/Norm is a duo of libraries that provide a simple yet full featured interface to perform script based queries as well as adds extended functionality such as ORM (with easy and dynamic relationships), oData (Consume/Produce), LINQ style queries and more.  Basically it is the data interaction ColdFusion/Railo/Lucee should have come with out of the box.

In short, the goal of this library is to allow one to interact with the database in a DB platform agnostic way, while making it super easy.

# Requirements
Currently this library has been actively used and tested on Lucee 4x, CF11+

# Installation
## Manual
Clone this repo and copy the "database" folder `(/database)` into your project (or into the folder you place your components)
## CommandBox
`box install dao`

# Resources

**[Documentation:](https://github.com/abramadams/dao/wiki)**

**Chat:** The [CFML team Slack](http://cfml-slack.herokuapp.com) - Ask questions in the [#cfml-general channel](https://cfml.slack.com/messages/cfml-general/) and mention @abram.

# Contributing
Pull requests welcome! See [installation instructions](https://github.com/abramadams/dao/blob/master/installInstructions.md) for setup and testing.

# Copyright and License

Copyright (c) 2009-2017 Abram Adams. All rights reserved.
The use and distribution terms for this software are covered by the Apache Software License 2.0 (http://www.apache.org/licenses/LICENSE-2.0) which can also be found in the file LICENSE at the root of this distribution and in individual licensed files.
By using this software in any fashion, you are agreeing to be bound by the terms of this license. You must not remove this notice, or any other, from this software.