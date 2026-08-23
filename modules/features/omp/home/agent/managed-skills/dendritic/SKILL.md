Dendritic Nix Purpose Use this skill when designing, reviewing, refactoring, or
extending Nix configurations using the Dendritic Pattern.

The central idea is:

Treat every non-entry-point Nix file as a top-level Nixpkgs module, and organize
those modules around features rather than configuration classes or hosts.

Dendritic is a module-system architecture pattern, not a mandatory framework. It
can commonly be implemented with flake-parts, but it can also be implemented
directly with lib.evalModules or another top-level module system. G GitHub

Core mental model Think in three layers:

                       top-level module system
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
           features          values           factories
              │                 │                 │
      ┌───────┼────────┐        │        ┌────────┼────────┐
      ▼       ▼        ▼        ▼        ▼        ▼        ▼
    NixOS  HomeMgr  Darwin   packages   users   hosts   systems
      │       │        │
      └───────┴────────┘
           lower-level
           configurations

The top-level module system is the architectural composition layer.

NixOS, Home Manager, nix-darwin, and other configuration classes are values
produced or assembled by that layer, rather than being the primary
organizational boundary.

A feature may contribute to several configuration classes simultaneously.

For example, a niri feature might contain:

{ ... }: { nixos.modules.desktop = { programs.niri.enable = true; };

homeManager.modules.desktop = { programs.niri.enable = true; }; }

The exact option names and schema are project-specific; the important principle
is that the feature owns all of its relevant configuration.

Required knowledge A user working with this pattern should understand:

the Nix language the Nixpkgs module system lib.mkOption module option merging
lib.types.deferredModule lib.evalModules NixOS module evaluation Home Manager
module evaluation flakes optionally, flake-parts The Dendritic pattern relies
heavily on the fact that the Nix module system is itself a powerful
data-composition mechanism. G GitHub

Fundamental rules

1. Every ordinary Nix file is a top-level module Apart from explicit entry
   points, assume that:

foo.nix bar.nix features/niri.nix users/alice.nix hosts/laptop.nix

are all top-level modules.

Avoid mixing arbitrary expression files into the automatically imported tree.

Reasonable exceptions include package expressions used with callPackage. A
convention such as:

foo.pkg.nix

can distinguish these from top-level modules and cause the importer to skip
them. G GitHub

2. A module should represent one feature Prefer:

modules/ audio.nix bluetooth.nix containers.nix desktop.nix development.nix
git.nix monitoring.nix

over:

modules/ nixos/ configuration.nix home-manager/ configuration.nix hosts/
laptop.nix desktop.nix

The distinction is important:

Organize around what the system does, not which evaluator eventually consumes
it.

A feature can span:

NixOS Home Manager nix-darwin flake outputs packages development shells checks
deployment configuration other custom module classes 3. Paths name features, not
evaluation semantics A path should help answer:

"What feature is this?"

rather than:

"Which evaluator reads this?"

Good:

modules/ firefox.nix gaming.nix virtualization.nix workstation.nix

Less useful:

modules/ nixos/ home-manager/ darwin/

Because every file is a top-level module, moving or splitting a feature should
not require changing the fundamental evaluation architecture. G GitHub

Automatic importing Automatic importing is one of the major benefits of the
pattern.

The importer should generally:

recursively discover Nix files exclude entry points exclude explicitly ignored
files import every remaining module into the top-level module system For
example:

flake.nix modules/ _internal.nix firefox.nix niri.nix packages.pkg.nix users/
alice.nix

could result in:

imported: modules/firefox.nix modules/niri.nix modules/users/alice.nix

ignored: modules/_internal.nix modules/packages.pkg.nix flake.nix

A small importer library such as import-tree may be used, or the importer can be
implemented locally. G GitHub

Important consequence Do not make file paths carry hidden semantics.

If a module must be imported differently merely because it moved from:

modules/foo.nix

to:

modules/bar/foo.nix

the architecture is probably relying too heavily on directory structure.

Declare your own module options One of the most important Dendritic techniques
is to model the architecture explicitly through module options.

Instead of depending exclusively on pre-existing framework options, declare
options representing your own conceptual model.

For example:

{ lib, ... }:

{ options.nixos.modules.base = lib.mkOption { type = lib.types.deferredModule;
}; }

Another feature can then compose it:

{ config, lib, ... }:

{ options.nixos.modules.workstation = lib.mkOption { type =
lib.types.deferredModule; };

config.nixos.modules.workstation = config.nixos.modules.base; }

This allows the module system to become the representation of the architecture
itself.

The configuration is no longer merely using a module system.

It is describing its own composition graph using a module system. G GitHub

Deferred modules Use lib.types.deferredModule when an option represents a module
that will be evaluated later in another module system.

Conceptually:

options.nixos.modules.foo = lib.mkOption { type = lib.types.deferredModule; };

means:

top-level evaluation │ │ constructs ▼ NixOS module │ │ later evaluated by ▼
NixOS module system

This distinction is crucial.

Do not confuse:

config.nixos.modules.foo

with an already evaluated NixOS configuration.

It is a module value that can participate in a later evaluation.

Merge instead of proliferate Avoid creating a unique named lower-level module
for every tiny component.

Prefer:

nixos.modules.workstation

containing several related contributions:

audio bluetooth graphics networking fonts desktop

when those features are intentionally part of the same configuration
composition.

Otherwise, consumers end up with increasingly large import lists:

imports = [ audio graphics fonts bluetooth networking ... ];

and every new feature requires updating many lists.

Instead, use module-system merging to compose several top-level feature modules
under a meaningful lower-level module name. G GitHub

Rule of thumb Create a named lower-level module when it represents a useful
composition boundary, not merely because a feature exists.

Avoid specialArgs as an application architecture In conventional Nix
architectures, values are frequently threaded through:

specialArgs

and:

extraSpecialArgs

until they reach the module that needs them.

Dendritic architecture can often eliminate much of this plumbing.

Instead of:

flake │ ├─ specialArgs │ │ │ ▼ │ NixOS │ │ │ ├─ extraSpecialArgs │ │ │ │ │ ▼ │ │
Home Manager

prefer:

         top-level config
          /     |      \
         /      |       \
    package   function   value
       \        |        /
        \       |       /
         lower-level modules

A top-level module can expose a value through config, and another top-level
module can consume it.

For example:

# modules/scripts/foo.nix

{ config, pkgs, ... }:

{ my.scripts.foo = pkgs.writeShellScriptBin "foo" '' echo hello ''; }

and:

# modules/development.nix

{ config, ... }:

{ nixos.modules.workstation = { environment.systemPackages = [
config.my.scripts.foo ]; }; }

The top-level configuration becomes the shared dependency context.

Feature-oriented design When adding something, ask:

What is the feature?

rather than:

Which machine gets this?

For example, instead of:

hosts/laptop.nix hosts/desktop.nix hosts/server.nix

with duplicated feature configuration, create:

features/ audio.nix desktop.nix development.nix gaming.nix monitoring.nix

Then make host compositions select or aggregate those features.

This reduces duplication and makes cross-cutting concerns explicit.

Hosts are compositions A host should generally be relatively boring.

A host describes:

Which features does this machine have?

rather than:

How is every feature implemented?

For example:

{ nixos.modules.laptop = { imports = [ config.nixos.modules.base
config.nixos.modules.desktop config.nixos.modules.development ]; }; }

The exact structure is project-dependent, but the principle is stable:

hosts compose features; features implement behavior.

Users are compositions too Users should be treated similarly.

Avoid putting the complete implementation of:

Git shell editors browsers SSH development tools desktop applications

inside a single user module.

Instead, model those as features and let a user select a composition.

For example:

features/ git.nix shell.nix neovim.nix development.nix

users/ alice.nix bob.nix

The user module answers:

What does Alice use?

while the feature module answers:

How is Git configured?

Multi-class features A powerful use of Dendritic is allowing one feature to
affect several module classes.

For example, a feature might contain:

{ nixos.modules.desktop = { services.displayManager.enable = true; };

homeManager.modules.desktop = { programs.waybar.enable = true; };

darwin.modules.desktop = { # Darwin-specific implementation }; }

The feature remains conceptually unified even though its implementation crosses
evaluators.

This is one of the main reasons to avoid organizing the source tree primarily
by:

nixos/ home-manager/ darwin/

Cross-cutting features are easier to discover and maintain when their
implementations live together.

Factories Use factories when the configuration contains repeated structures that
vary by parameters.

Typical examples:

users hosts machines VMs development environments deployment targets

A factory can turn declarative data into modules.

Conceptually:

userModule = { name, extraGroups, shell, }: {

# generated module

};

Then:

users.alice = userModule { name = "alice"; extraGroups = [ "wheel" ]; shell =
pkgs.zsh; };

Factories are especially useful when a single conceptual entity spans multiple
module classes.

However, do not introduce factories merely to avoid writing a few lines of Nix.

Prefer direct module composition until repetition or parametrization becomes
meaningful.

Recent Dendritic community discussion demonstrates factory patterns being used
to coordinate NixOS and Home Manager modules for users. G GitHub

Tags and capabilities For larger configurations, consider expressing
relationships through capabilities rather than hard-coded host lists.

Instead of:

hostA = [ "graphics" "audio" "desktop" ]; hostB = [ "graphics" "audio" ];

think in terms of:

desktop requires graphics requires audio

development requires git requires shell

gaming requires graphics requires audio

This naturally leads toward a dependency graph.

A feature can declare:

what it provides what it consumes what it composes

The Nix module system can then perform the actual merging.

Do not build a complicated custom dependency framework unless the configuration
actually needs one.

Dependency direction Prefer dependencies that flow through the top-level
configuration:

feature ↓ top-level option ↓ composition ↓ lower-level module

Avoid hidden dependencies through:

relative imports specialArgs plumbing implicit global variables directory
conventions duplicated host configuration

A useful review question is:

Can I understand this feature by reading its module and the options it consumes?

If not, look for hidden coupling.

enable options Do not automatically create:

programs.foo.enable = true;

style options for every custom feature.

In ordinary NixOS modules, enable options are often useful because many NixOS
modules are imported globally and selectively activated.

In a Dendritic architecture, importing a feature module can itself be the
activation mechanism.

For example:

config.nixos.modules.desktop = {

# desktop feature is active here

};

does not necessarily need:

config.nixos.modules.desktop = { my.desktop.enable = true; };

unless there is a real reason to distinguish:

module is available

from:

feature is enabled

The original Dendritic guidance explicitly calls unnecessary enable options an
anti-pattern. G GitHub

Packages are allowed to be different Not every Nix expression needs to be a
module.

Package definitions often naturally belong to:

callPackage

or similar mechanisms.

A practical convention is:

foo.pkg.nix

for package expressions that should be excluded from automatic top-level-module
importing.

This is an intentional exception, not a failure of the architecture. G GitHub

Naming conventions Prefer names that describe concepts:

desktop.nix development.nix firefox.nix git.nix monitoring.nix niri.nix
virtualization.nix

Avoid names that describe implementation mechanics:

module1.nix common.nix misc.nix configuration.nix stuff.nix helpers.nix

A module should ideally have one obvious noun or feature associated with it.

If common.nix grows large, split it by feature.

File size and splitting A feature does not need to fit into one physical file
forever.

The Dendritic pattern intentionally makes splitting and moving modules cheap.

If:

desktop.nix

becomes too large, it can become:

desktop/ compositor.nix notifications.nix panel.nix portals.nix

provided those files still represent top-level modules.

The directory structure is for human organization; automatic importing handles
discovery.

Cross-platform configuration When supporting:

NixOS nix-darwin Home Manager avoid creating three completely independent
implementations when a feature is conceptually one thing.

Instead:

features/ shell.nix development.nix desktop.nix

can contain class-specific contributions.

Conceptually:

          development
         /     |      \
        /      |       \
    NixOS   HomeMgr   Darwin

This keeps the architecture aligned with the user's mental model.

Testing and validation Dendritic configurations should be validated at multiple
levels.

Syntax Use:

nix fmt nix flake check

as appropriate.

Evaluation Evaluate individual outputs:

nix eval nix build

or the relevant NixOS/Home Manager/Darwin output.

Module composition When adding a feature, verify:

the feature module evaluates by itself where appropriate the intended
lower-level module receives it multiple features merge correctly unrelated
configurations do not accidentally inherit it platform-specific portions remain
isolated Graph debugging When available, inspect the module/configuration graph
to understand:

Who imported this? Why is this option defined? Which modules contributed this
value?

This is particularly useful in large module graphs.

Migration strategy Do not rewrite a mature Nix configuration all at once.

A useful migration sequence is:

Step 1 — Identify entry points Keep:

flake.nix

and any other genuine entry points.

Step 2 — Establish a top-level module system Usually this means flake-parts, but
the pattern does not require it.

Step 3 — Automatically import feature modules Make ordinary Nix files top-level
modules.

Step 4 — Extract features Move duplicated functionality into modules such as:

git shell desktop audio development

Step 5 — Introduce deferred-module options Represent lower-level modules as
top-level option values.

Step 6 — Replace special-argument plumbing Move shared values into the top-level
configuration.

Step 7 — Simplify hosts Turn hosts into compositions of features.

Step 8 — Simplify users Do the same for users.

Step 9 — Remove unnecessary enable switches Where importing the feature already
provides the desired semantics.

Step 10 — Keep sensible exceptions Do not force package expressions, generated
files, or unusual tooling into the pattern merely for ideological consistency.

Common anti-patterns Host-first architecture hosts/ laptop.nix desktop.nix

where each host duplicates almost everything.

Prefer reusable feature modules and thin host compositions.

Class-first architecture nixos/ home-manager/ darwin/

where cross-cutting features are scattered across unrelated directories.

Prefer feature-first organization.

Import spaghetti A host contains dozens of direct imports:

imports = [ ./audio.nix ./graphics.nix ./fonts.nix ./bluetooth.nix
./networking.nix ./desktop.nix ./... ];

Prefer meaningful composition modules.

SpecialArgs plumbing Passing the same values through multiple layers of
specialArgs and extraSpecialArgs.

Prefer top-level module options and configuration values.

Giant common.nix A module that contains every shared setting.

Prefer splitting it by feature.

Overly granular lower-level modules Hundreds of names such as:

nixos.modules.audio nixos.modules.bluetooth nixos.modules.fonts
nixos.modules.graphics ...

when they are always consumed together.

Merge related contributions under a meaningful composition.

Everything gets an enable Do not recreate NixOS's globally-imported-module model
inside your own module tree.

Importing a feature can be sufficient to activate it.

Overengineering factories Do not create a factory abstraction before there is
meaningful repetition.

Simple Nix is often better than an abstraction.

Review checklist When reviewing a Dendritic configuration, ask:

Is every ordinary Nix file a top-level module? Are genuine entry points
explicitly excluded? Are package expressions clearly separated? Does each module
represent one feature? Does the path communicate the feature? Are features
organized independently of configuration class? Can one feature contribute to
multiple module classes? Are lower-level modules represented with appropriate
deferredModule options? Are related lower-level modules merged rather than
excessively proliferated? Is specialArgs being used only where genuinely
necessary? Are hosts mostly compositions rather than implementations? Are users
mostly compositions rather than implementations? Are enable options actually
needed? Are factories justified by repetition or parameterization? Are
cross-cutting concerns visible in one place? Can features be moved or split
without changing their semantics? Is automatic importing predictable? Are there
clear conventions for files that must not be imported? Can the module graph be
understood without following a maze of relative imports? Design philosophy
Dendritic should make the architecture emerge from the module system rather than
from an elaborate directory convention.

The goal is not:

"Put NixOS files in one directory and Home Manager files in another."

The goal is:

"Model the system as a collection of composable features, and let the module
system assemble those features into the configurations that need them."

This is why the pattern works particularly well for configurations with:

many hosts multiple operating systems multiple users NixOS + Home Manager
nesting shared packages and functions cross-cutting features repeated
machine/user compositions The pattern is deliberately pragmatic. It is a tool
for reducing architectural friction, not a rule that every Nix repository must
follow. The original author explicitly recommends making exceptions where
appropriate. G GitHub

Compact heuristic When adding a new piece of configuration, ask:

What feature does this implement? │ ▼ Create a top-level module │ ▼ Expose
reusable values/modules through top-level options │ ▼ Compose lower-level
modules with deferredModule │ ▼ Keep hosts/users as compositions │ ▼
Automatically import the feature

If the answer instead requires:

Which host directory? Which evaluator directory? Which specialArgs layer? Which
relative import
