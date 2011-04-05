# classes providing access to directories of EDI standards like
# the UN Trade Data Interchange Directories (UNTDID) and Subsets,
# or ISO7389, or SAP IDoc definitions.
#
# Part of  the EDI module "edi4r", a class library
# to parse and create UN/EDIFACT and other EDI data
#
# :include: ../../AuthorCopyright
#
# $Id: standards.rb,v 1.9 2006/08/01 11:00:35 werntges Exp $
#--
# $Log: standards.rb,v $
# Revision 1.9  2006/08/01 11:00:35  werntges
# EDI_NDB_PATH: Now platform independent
#
# Revision 1.8  2006/05/26 16:55:38  werntges
# V 0.9.3 snapshot. RDoc added, some renaming & cleanup.
#
# Revision 1.7  2006/04/28 14:26:30  werntges
# 0.9.1 snapshot
#
# Revision 1.6  2006/03/28 22:21:35  werntges
# changed to symbols as parameter keys, e.g. "d0051" to :d0051
#
# Revision 1.5  2006/03/22 16:51:29  werntges
# snapshot after edi4r-0.8.2.gem
#
# Revision 1.4  2004/02/19 17:33:34  heinz
# HWW: Snapshot after REMADV mapping (no changes here, just testing)
#
# Revision 1.3  2004/02/14 12:11:03  heinz
# HWW: Minor improvements
#
# Revision 1.2  2004/02/11 23:35:35  heinz
# HWW: Caching bug fixed, each_BCDS_entry revised, IDoc support added
#
# Revision 1.1  2004/02/09 16:31:13  heinz
# Initial revision
#
# To-do list:
#  all	- Major refactoring would be a good idea... just starting this ;-)
#  err  - More error classes, maintained separately
#++

# Module EDI::Dir
# Collection of Structs and classes for EDI Directory management

module EDI
  module Dir

    DE_Properties = Struct.new( :name, :format, :status, :dummy, :description)

    # Common structure of B)ranch (of a msg), C)DE, D)E, S)egment
    #
    BCDS_entry = Struct.new( :item_no, :name, :status, :maxrep)

    # Named_list:
    #
    # A simplified Array to represent objects of EDI classes CDE, Segment, and
    # Message (branches) as lists of their constituting sub-units, augmented
    # by the common properties +name+ and +desc+ (description).
    #
    class Named_list
      attr_accessor :name, :desc

      def initialize
        @name, @desc, @store = nil, nil, []
      end

      def <<(obj)
        @store << obj
      end

      def each( &b )
        @store.each( &b )
      end

      def size
        @store.size
      end

      def empty?
        @store.empty?
      end
    end


    # A Directory object is currently a set of hashes representing
    # all the entries for data elements, composites, segments, and messages.
    #
    class Directory
      #
      # Some ingredients for Directory caching:
      #
      @@cache = {}
      @@caching = true
      private_class_method :new

      # As long as we employ plain CSV files to store directories, a Directory
      # can become quite memory-consuming.
      # Therefore Directorys are cached after creation, so that they
      # need to be created and maintained only once when there areeseveral
      # messages of the same type in an interchange.
      #
      # Turns off this caching mechanism, saving memory but costing time.
      #
      def Directory.caching_off
        @@caching = false
      end

      # Turns on caching (default setting), saving time but costing memory.
      #
      def Directory.caching_on
        @@caching = true
      end

      # Tells if caching is currently activated (returns a boolean)
      #
      def Directory.caching?
        @@caching
      end

      # Releases memory by flushing the cache. Needed primarily for unit tests,
      # where many if not all available diagrams are created.
      #
      def Directory.flush_cache
        @@cache = {}
      end


      # Creates (and caches) a new directory. Returns reference to
      # existing directory when already in cache.
      #
      # std:: The syntax standard key. Currently supported:
      #       - 'E' (EDIFACT),
      #       - 'I' (SAP IDOC)
      # params:: A hash of parameters that uniquely identify the selected dir.
      #          Hash parameters use following alternative key sets:
      #
      # ISO9735::  :d0002, :d0076 (default: "", nil)
      # UN/TDID::  :d0065, :d0052, :d0054, :d0051, :d0057; :is_iedi
      # SAP IDOC:: :IDOCTYPE, :SAPTYPE, :EXTENSION (see EDI_DC fields)
      #
      # UN/TDID: Elements of S009 or S320 are used:
      # d0065:: Message type like "INVOIC"
      # d0052:: Message version number, like "90" or "D"
      # d0054:: Message release number, like "1" or "03A"
      # d0051:: Controlling agency, like "UN" or "EN"
      # d0057:: Association assigned code (optional), like "EAN008"
      #
      # Interactive EDI (only limited supported so far):
      # is_iedi:: Flag, +true+ or +false+. Assumed +false+ if missing.
      #
      def Directory.create( std, params )

        case std
        when 'E' # UN/EDIFACT
          par = {:d0051 => '',
                 :d0057 => '',
                 :is_iedi => false }.update( params )
        when 'I' # SAP IDocs
          par = { }.update( params )
        else
          raise "Unsupported syntax standard: #{std}"
        end

        if Directory.caching?

          # Use param set as key for caching
          #
          key = par.sort {|a,b| a.to_s <=> b.to_s}.hash
          obj = @@cache[key]
          return obj unless obj.nil?

          obj = new( std, par )
          @@cache[key] = obj # cache & return it

        else
          new( std, par )
        end
      end

      #
      # Helper method: Derive path fragments of CSV files from parameters
      #
      def Directory.prefix_ext_finder( std, par )
        ext = ''
        case std

        when 'I' # SAP IDocs
          prefix = '/sap'
          if par[:IDOCTYPE]
            prefix += '/idocs'+par[:SAPTYPE]+'/'+par[:IDOCTYPE]+'/'
            if par[:EXTENSION].is_a? String and not par[:EXTENSION].empty?
              if par[:EXTENSION] =~ /\/(.*\/)([^\/]+)/
                prefix += $1 + 'ED'
                ext = $2 + '.csv'
              else
                prefix += 'ED'
                ext = par[:EXTENSION] + '.csv'
              end
            else
              prefix += 'ED'
              ext = '.csv'
            end
          else
            case par[:SAPTYPE]
            when '40'; ext = '04000'
            else ; raise "Unsupported SAP Type: #{par[:SAPTYPE]}"
            end
            prefix += '/controls/SD'
            ext += '.csv'
          end

        when 'E' # UN/EDIFACT
          prefix = '/edifact'
          if par[:d0002] # ISO9735 requested?
            case par[:d0002]
            when 1
              ext = '10000'
            when 2
              ext = '20000'
            when 3
              ext = '30000'
            when 4
              # Assume that any setting of d0076 implies SV 4-1
              # Revise when SV 4-2 arrives!
              ext = (par[:d0076] == nil) ? '40000' : '40100'
            else
              raise "Invalid syntax version: #{par[:d0002]}"
            end
            prefix += '/iso9735/SD'
            ext += '.csv'

          else		# UN/TDID requested?
            prefix += par[:is_iedi] ? '/untdid/ID' : '/untdid/ED'
            ext = (par[:d0052]+par[:d0054]).downcase + '.csv'
          end

        else
          raise "Unsupported syntax standard: #{std}"
        end

        return prefix, ext
      end


      #
      # Helper method: Determine path of requested csv file
      #
      # Will be generalized to a lookup scheme!
      #
      def Directory.path_finder( prefix, ext, selector )
        filename = prefix + selector + '.' + ext
        searchpath = ENV['EDI_NDB_PATH']

        searchpath.split(/#{File::PATH_SEPARATOR}/).each do |datadir|
          path = datadir + filename
          return path if File.readable? path
        end
        raise "No readable file '." + filename + "' found below any dir on '" + searchpath + "'"
      end

      #
      # see Directory.create
      #
      def initialize ( std, par ) # :nodoc:

        prefix, ext = Directory.prefix_ext_finder( std, par )

        # Build DE directory

        prefix_ed = prefix.sub(/ID$/, 'ED') # There is no IDED.*.csv!
        csvFileName = Directory.path_finder(prefix_ed, ext, 'ED' )
        @de_dir = Hash.new
        IO.foreach(csvFileName) do |line|
          d = DE_Properties.new
          d.name, d.format, d.dummy, d.description = line.strip.split(/;/)
          $stderr.puts "ERR DE line", line if d.description.nil?
          @de_dir[d.name] = d
        end

        # Build CDE directory

        csvFileName = Directory.path_finder(prefix, ext, 'CD' )
        @cde_dir = Hash.new
        IO.foreach(csvFileName) do |line|
          c = Named_list.new
          c.name, c.desc, list = line.split(/;/, 3)
          $stderr.puts "ERR CDE line", line if list.nil?
          list.sub(/;\s*$/,'').split(/;/).each_slice(4) do |item, code, status, fmt|
            $stderr.puts "ERR CDE list", line if fmt.nil?
            c << BCDS_entry.new( item, code, status, 1 )
          end
          @cde_dir[c.name] = c
        end

        # Build Segment directory

        csvFileName = Directory.path_finder(prefix, ext, 'SD' )
        @seg_dir = Hash.new
        IO.foreach(csvFileName) do |line|
          c = Named_list.new
          c.name, c.desc, list = line.split(/;/, 3)
          $stderr.puts "ERR SEG line", line if list.nil?
          list.sub(/;\s*$/,'').split(/;/).each_slice(4) do |item, code, status, maxrep|
            $stderr.puts "ERR SEG list", line if maxrep.nil?
            c << BCDS_entry.new( item, code, status, maxrep.to_i )
          end
          @seg_dir[c.name] = c
        end

        # Build Message directory

        csvFileName = Directory.path_finder(prefix, ext, 'MD' )
        @msg_dir = Hash.new
        re = if par[:d0065] and par[:d0065] =~ /([A-Z]{6})/
             then Regexp.new($1) else nil end
        IO.foreach(csvFileName) do |line|
          next if re and line !~ re # Only lines matching message type if given
          c = Named_list.new
          c.name, c.desc, list = line.split(/;/, 3)
          $stderr.puts "ERR MSG line", line if list.nil?
          list.sub(/;\s*$/,'').split(/;/).each_slice(3) do |code, status, maxrep|
            $stderr.puts "ERR MSG list", line if maxrep.nil?
            c << BCDS_entry.new( "0000", code, status, maxrep.to_i )
          end
          @msg_dir[c.name] = c
        end
      end # initialize


      # Returns CSV line for DE called +name+.
      # If +name+ is a Regexp, returns the first match or +nil+.
      #
      def de( name )
        if name.is_a? Regexp
          @de_dir[ @de_dir.keys.find {|key| key =~ name} ]
        else
          @de_dir[name]
        end
      end

      # Returns a sorted list of names of available DE
      #
      def de_names
        @de_dir.keys.sort
      end


      # Returns CSV line for CDE called +name+.
      #
      def cde( name )
        @cde_dir[name]
      end

      # Returns a sorted list of names of available CDE
      #
      def cde_names
        @cde_dir.keys.sort
      end


      # Returns CSV line for segment called +name+.
      # If +name+ is a Regexp, returns the first match or +nil+.
      #
      def segment( name )
        if name.is_a? Regexp
          @seg_dir[ @seg_dir.keys.find {|key| key =~ name} ]
        else
          @seg_dir[name]
        end
      end

      # Returns a sorted list of names of available segments
      #
      def segment_names
        @seg_dir.keys.sort
      end


      # Returns CSV line of top branch for message called +name+.
      #
      def message( name ) # Actually, only one branch!
#        $stderr.puts name
        @msg_dir[name]
      end

      # Returns a sorted list of names of available messages
      #
      def message_names
        @msg_dir.keys.sort
      end


      # Iterates over each branch (message), composite, data element,
      # or segment found (hence: BCDS) that is matched by +id+.
      #
      # +id+ is a string. The object type requested by this string is not
      # obvious. This method determines it through a naming convention.
      # See source for details.
      #
      # Fails with EDI::EDILookupError when nothing found.

      def each_BCDS( id, &b )
        list = nil
        case id
        when /^[CES]\d{3}$/	# C)omposite
          list = cde(id)

        when /^\d{4}$/		# Simple D)E
          list = de(id)

        when /^[A-Z][A-Z0-9]{2}$/	# S)egment
          list = segment(id)

        when /^[A-Z]{6}:$/	# Message B)ranch
          list = message(id)

          # Workaround for the IDoc case:
          # We identify entry type by a (intermediate) prefix
          #
        when /^d(.*)$/		# Simple D)E
          list = de($1)

        when /^s(.*)$/		# S)egment, SAP IDOC
          list = segment($1)

        when /^m(.*)$/		# Message B)ranch
          list = message($1)

        else			# Should never occur
          raise IndexError, "Not a legal BCDS entry id: '#{id}'"
        end

        raise EDILookupError, "#{id} not in directory!" if list.nil?
        list.each( &b )
      end

    end # Directory

  end # module Dir

  # Special Exception class that sometimes gets rescued
  #
  class EDILookupError < IndexError
  end

end # module EDI


# :enddoc:
if __FILE__ == $0
  # Test code

  require 'enumerator'
  require 'pathname'

  # Make this file standalone during testing:
  ENV['EDI_NDB_PATH'] =
    Pathname.new(__FILE__).parent.parent.parent.to_s+'/data'

  # EDIFACT tests

  d = EDI::Dir::Directory.create('E',
                                 :d0065 => 'ORDERS',
                                 :d0052 =>'D',
                                 :d0054 =>'96A')
  i = EDI::Dir::Directory.create('E', :d0002 => 2)

  puts i.de_names; gets
  puts i.cde_names; gets
  puts d.message_names; gets
  puts d.de('4457'); gets

  # EDIFACT bulk tests

  d = EDI::Dir::Directory.create('E',
                                 :d0052 =>'D',
                                 :d0054 =>'96A')

  puts d.message_names; gets

  # SAP IDOC tests (should fail now!)

  s = EDI::Dir::Directory.create('I',
                                 :SAPTYPE => '40',
                                 :IDOCTYPE => 'ORDERS04')
  t = EDI::Dir::Directory.create('I',
                                 :SAPTYPE => '40',
                                 :IDOCTYPE => 'ORDERS05',
                                 :EXTENSION => '/GIL/EPG_ORDERS05')
  puts s.de_names
  puts t.de_names
end
