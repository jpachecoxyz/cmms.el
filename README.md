
# Table of Contents

1.  [Philosophy](#orgf824041)
2.  [Features](#orgb2e08a0)
3.  [Installation](#orgb23cebe)
4.  [Configuration](#org88cf15f)
5.  [Usage](#org3f1b3c7)
6.  [Data Structure](#orge8daf77)
7.  [Injection](#orgf61b23a)
    1.  [IDRA 400](#org79c5862)
8.  [Assembly](#orgcb618c8)
9.  [WO 202604041530](#org820b847)
10. [Roadmap](#orgb2e9b21)
11. [Why Emacs?](#org20ba781)
12. [Contributing](#orge32329d)
13. [License](#org4164e46)

EMMS (Emacs Maintenance Management System) is a lightweight
Computerized Maintenance Management System (CMMS) implemented
entirely in Emacs using Org Mode.

It allows users to manage:

-   Areas
-   Assets
-   Work Orders

All data is stored in plain Org files, making it portable,
versionable, and easy to integrate with the Emacs ecosystem.


<a id="orgf824041"></a>

# Philosophy

EMMS follows the Emacs philosophy:

-   Plain text data
-   Extensible
-   Hackable
-   Keyboard driven
-   No external database required

Everything lives inside Org files.


<a id="orgb2e08a0"></a>

# Features

Current features:

-   Create maintenance **Areas**
-   Register **Assets**
-   Generate **Work Orders**
-   Asset and area validation
-   Org-based data storage
-   Simple dashboard interface

Planned features:

-   Asset explorer UI
-   Work order status tracking
-   Maintenance history per asset
-   Preventive maintenance scheduling
-   Org Agenda integration
-   Multi-user data directories
-   Reporting


<a id="orgb23cebe"></a>

# Installation

Clone the repository:

    git clone https://github.com/jpachecoxyz/emms.el

Add it to your Emacs configuration:

    (add-to-list 'load-path "/path/to/emms.el")
    (require 'emms)


<a id="org88cf15f"></a>

# Configuration

By default EMMS stores its data in:

    /tmp/emms/

You can customize this:

    (setq emms-directory "~/emacs/emms/")

Files created:

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">File</th>
<th scope="col" class="org-left">Purpose</th>
</tr>
</thead>
<tbody>
<tr>
<td class="org-left">assets.org</td>
<td class="org-left">Areas and assets</td>
</tr>

<tr>
<td class="org-left">workorders.org</td>
<td class="org-left">Maintenance work orders</td>
</tr>
</tbody>
</table>


<a id="org3f1b3c7"></a>

# Usage

Main keybinding:

    C-c m

Available commands:

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">Key</th>
<th scope="col" class="org-left">Action</th>
</tr>
</thead>
<tbody>
<tr>
<td class="org-left">a</td>
<td class="org-left">Create Area</td>
</tr>

<tr>
<td class="org-left">e</td>
<td class="org-left">Create Asset</td>
</tr>

<tr>
<td class="org-left">w</td>
<td class="org-left">Create Work Order</td>
</tr>
</tbody>
</table>

Example:

    C-c m a

Create an area:

    Injection

Add an asset:

    C-c m e

Example:

    IDRA 400
    Area: Injection

Create a work order:

    C-c m w


<a id="orge8daf77"></a>

# Data Structure

Assets are stored inside areas:

\#+begin<sub>src</sub> org


<a id="orgf61b23a"></a>

# Injection


<a id="org79c5862"></a>

## IDRA 400


<a id="orgcb618c8"></a>

# Assembly

\#+end<sub>src</sub>

Work orders:

\#+begin<sub>src</sub> org


<a id="org820b847"></a>

# WO 202604041530

Hydraulic oil leak detected
\#+end<sub>src</sub>


<a id="orgb2e9b21"></a>

# Roadmap

Planned improvements:

-   [ ] Interactive dashboard
-   [ ] Asset explorer tree
-   [ ] Work order lifecycle
-   [ ] Preventive maintenance
-   [ ] Org Agenda integration
-   [ ] Reports
-   [ ] MELPA package release


<a id="org20ba781"></a>

# Why Emacs?

Most CMMS systems are:

-   Expensive
-   Closed
-   Web-based
-   Hard to customize

EMMS is:

-   Free
-   Hackable
-   Local-first
-   Scriptable


<a id="orge32329d"></a>

# Contributing

Pull requests and suggestions are welcome.

Repository:

<https://github.com/jpachecoxyz/emms.el>


<a id="org4164e46"></a>

# License

MIT License

