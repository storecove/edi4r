Tutorial
========

Getting started
---------------

### Installation

sudo gem install edi4r sudo gem install edi4r-tdid

### Require statements

require “rubygems” require “edi4r” \# Try require\_gem if this fails on
your site require “edi4r/edifact” require “edi4r-tdid” \# Try
require\_gem if this fails on your site

Creating an (outbound) UN/EDIFACT interchange
---------------------------------------------

### An empty interchange

ic = EDI::E::Interchange.new

creates an empty interchange object with syntax version 3 and charset
UNOB. You can make this a bit more explicit by passing parameters as
hash components:

ic = EDI::E::Interchange.new( :version =\> 3, :charset =\> ‘UNOB’ )

See the source for more parameters.

### An empty message

msg = ic.new\_message

creates an empty message in the context of the given interchange,
i.e. the syntax version, charset, UNA settings, interactive or batch
EDI.

By default, the message type is <tt>ORDERS D.96A</tt>. Select any
message from any UN/TDID by passing the corresponding parameters as hash
components:

msg = ic.new\_message( :msg\_type=\>‘ORDERS’, :version=\>‘D’,
:release=\>‘96A’, :resp\_agency=\>‘UN’ )

Hash components which you do not specify are taken from a set of
defaults.

### Filling an interchange

You may add messages to the interchange any time by calling method
add():

ic.add( msg )

When adding new messages to an interchange, they get appended to the
current interchange content. There is no method to insert a message at
any other location. If you need to do that, hold your messages in an
array, sort them any way you like, and finally add them to the
interchange in the desired sequence.

Note that each messag gets validated by default when you add it to the
interchange. If your message needs to be completed only later, you may
disable validation by calling:

ic.add( msg, false )

### Filling a message

A freshly created message is empty, aside from its header and trailer
which we shall discuss later. Simply create the segments you want to
add, fill them, and add them to the message:

seg = msg.new\_segment( ‘BGM’ )

Here, we derived a BGM segment from the current context, i.e. an UN/TDID
like D.96A which we specified when creating the message given.

Note that <tt>new\_segment()</tt> accepts all segment tags available in
the whole TDID’s segment directory - not just those usable within this
message type.

Add content to the segment (see below) and add it to the message:

msg.add( seg )

Like with messages added to an interchange, it is your responsibility to
assure the proper sequence of segments. You will need the UN/EDIFACT
message structure, a subset description, or a message implementation
guideline (MIG) handy in order to comply.

It is possible to add empty or partially filled segments to a message.
Just keep a reference to them and fill in their required data elements
later.

Accessing Composites and Data Elements
--------------------------------------

### Background

While interchanges and messages are basically empty when created,
segments are not
