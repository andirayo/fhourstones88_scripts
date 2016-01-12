require 'sinatra'
require 'open3'
require 'faraday'


SOLVER_FILE           = './C488'
EXPECT_SUBFOLDER      = 'fhourstones88/'
CONFIG_FILE_NAME      = 'expect_config'
EXPECT_CONFIG_FILE    = EXPECT_SUBFOLDER  +  CONFIG_FILE_NAME
EXPECT_COMMAND        = sprintf( 'cd %s;  expect %s', EXPECT_SUBFOLDER, CONFIG_FILE_NAME )
SOLVER_TIMEOUT        = 8  # seconds
BUFFER_SIZE           = 1024

OUTPUT_TIMEOUT        = '?'
OUTPUT_WIN            = '+'
OUTPUT_DRAW           = '='
OUTPUT_LOSS           = '-'
OUTPUT_MAYBE_LOSS     = '<'
OUTPUT_MAYBE_WIN      = '>'

RAW_EXPECT_CONFIG     = <<Rayo
#!/usr/bin/expect
eval spawn %s
send "%s\n"
interact

Rayo



check_game  = lambda do
  stream do |out|
    begin
      post_params = request.body.read.split('&').map {|e| e.split('=',2)}.to_h

      out << '<h1>Starting Evaluation!</h1><code style="color:#FFFFFF;background-color:#000000;white-space: pre-wrap;">' + "\n"
      sleep 1

      #game_number           = ARGV[0]   #|| '1118146'
      #website_type          = (ARGV[1]  ||  :german).to_sym
      game_number           = post_params['game_number']
      website_type          = post_params['website'].to_sym

      unless game_number  &&  ! game_number.to_s.empty?
        raise 'Please enter a game number (%s)!' % game_number
      end #unless

      if (Float(game_number)  rescue false)
        unless [:german,:dutch,:english].include?( website_type )
          raise 'Unknown website type %s' % website_type
        end #unless
        situation_to_be_solved  = nil

      else
        move_list               = game_number
        out << sprintf( "Current situation:  %s\n", move_list )

        situation_to_be_solved  = move_list.split(/,\s?/).map {|cell| cell[0].ord - 96}.join
        game_number = nil
      end #if-else







      def analyze_brettspielnetz_game( out, game_number, country )
=begin
=end
        out << sprintf( "Analyzing game %s!\n", game_number.to_s.capitalize )

        game_link_raw     = case country
                              when :german  ;  'http://www.brettspielnetz.de/vier+gewinnt/showusergame.php?gamenumber=%s'
                              when :dutch   ;  'http://www.jijbent.nl/4+op+een+rij/showusergame.php?gamenumber=%s'
                              when :english ;  'http://www.yourturnmyturn.com/connect+four/showusergame.php?gamenumber=%s'
                            end

        game_link         = game_link_raw % game_number
        out << game_link + "\n"

        http_client       = Faraday.new
        #headers          = { 'User-Agent' => 'Rayo Zuglist-Saver' }
        headers           = {
          'Connection'      => 'close',     #keep-alive
          'Pragma'          => 'no-cache',
          'Cache-Control'   => 'no-cache',
          'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'User-Agent'      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.90 Safari/537.36',
          'Accept-Encoding' => 'identity',  #gzip, deflate, sdch
          'Accept-Language' => 'en-US,en;q=0.8,de-DE;q=0.6,de;q=0.4',
        }
        http_response       = http_client.get( game_link, {}, headers )
        http_response_body  = http_response.body

        File.open('last_http_response_body.html.txt', 'w') {|f|f.write(http_response_body)}
=begin
=end
        http_response_body  = File.read('last_http_response_body.html.txt')

        errors  = []
        errors << 'Zugliste not found'  unless /(?<headline>Zugliste|Zettenlijst|Move list)(?<list_raw>.*?)<\/TABLE>/i =~ http_response_body
        moves = list_raw.scan( />(?<cell>[a-h][1-8]|aufg\.|[zZ]eit)(?:<\/font>)?(?:<\/[bB]>)?(?:<\/u>)?<\/a>/ )  if list_raw
        errors << 'Moves not parsed'  unless moves  &&  0 < moves.size
        errors << 'Players not found'  unless /blauwicoon\.gif.*?<a[^>]+?>(?<player_yellow>[^<]+?)(<\/a|&nbsp;?<img).*?<a[^>]+?>(?<player_red>[^<]+?)(<\/a|&nbsp;?<img)/ =~ http_response_body

        moves_sorted  = []
        if moves
          if 'Zugliste' == headline
            while 4 < moves.size
              moves_sorted.concat( moves[-4..-1] )
              moves = moves[0..-5]
            end #while
            moves_sorted.concat( moves ).flatten!
          else # ['Zettenlijst','Move list'].include?( headline )
            moves_sorted  = moves.flatten
          end #if
        end #if

        errors << 'Moves seem weird'  unless moves_sorted.first  &&  1 == moves_sorted.first[1].to_i    # sanity check: first move in 1st row?

        unless errors.empty?
          out << sprintf( "ERRORS: \n%s\n", errors )
          raise 'PenisException'
        end #unless



        move_list                 = moves_sorted.join( ', ' )
        out << sprintf( "Current situation:  %s\n" % move_list )

        moves_sorted_columns_only = moves_sorted.map {|cell| cell[0].ord - 96}.join

        return moves_sorted_columns_only
      end #analyze_brettspielnetz_game

      # Runs a specified shell command in a separate thread.
      # If it exceeds the given timeout in seconds, kills it.
      # Returns any output produced by the command (stdout or stderr) as a String.
      # Uses Kernel.select to wait up to the tick length (in seconds) between
      # checks on the command's status
      #
      # If you've got a cleaner way of doing this, I'd be interested to see it.
      # If you think you can do it with Ruby's Timeout module, think again.
      def run_with_timeout(out, command, target_output, timeout = SOLVER_TIMEOUT, tick = 0.5)
        output = ''
        begin
          # Start task in another thread, which spawns a process
          stdin, stderrout, thread = Open3.popen2e(command)
          # Get the pid of the spawned process
          pid = thread[:pid]
          start = Time.now

          while (Time.now - start) < timeout and thread.alive?
            out <<  '.'

            # Wait up to `tick` seconds for output/error data
            Kernel.select([stderrout], nil, nil, tick)
            # Try to read the data
            begin
              output << stderrout.read_nonblock(BUFFER_SIZE)
            rescue IO::WaitReadable
              # A read would block, so loop around for another select
            rescue EOFError
              # Command has completed, not really an error...
              output = 'SHIT'
              break
            end

            break  if target_output =~ output
          end
          # Give Ruby time to clean up the other thread
          sleep 1

          if thread.alive?
            # We need to kill the process, because killing the thread leaves
            # the process alive but detached, annoyingly enough.
            Process.kill("TERM", pid)
          end
        ensure
          stdin.close if stdin
          stderrout.close if stderrout
        end
        return output
      end #run_with_timeout

      def prepare_expect_config_and_solve( out, situation )
        expect_config     = sprintf( RAW_EXPECT_CONFIG, SOLVER_FILE, situation )
        File.open( EXPECT_CONFIG_FILE, 'w' ) {|f| f.write(expect_config)}

        result_parser     = /^score (?<result>[<>?+=-])/
        output            = run_with_timeout( out, EXPECT_COMMAND, result_parser )
        matches           = result_parser.match( output )
        if matches
          result = matches['result']
        elsif 'SHIT' == output
          out <<  "\nProblem! There is an issue finding or using the solver!\n"  %  SOLVER_TIMEOUT
          result = OUTPUT_TIMEOUT
        else
          out <<  "\nTimeout! Situation could not be solved within %s seconds. Unknown outcome!\n"  %  SOLVER_TIMEOUT
          result = OUTPUT_TIMEOUT
        end #unless

        return result
      end #prepare_expect_config_and_solve

      def column_full?( situation_to_be_solved, try )
        return 8 <= (situation_to_be_solved.chars.group_by{|e|e}.map{|k,v|[k,v.size]}.to_h[try.to_s]  ||  0)
      end #column_full?

      def solve_situation( out, situation_to_be_solved )
        best_result   = prepare_expect_config_and_solve( out, situation_to_be_solved )
        possibilities = Hash.new {|h,k|h[k] = []}

        out << "\nBest result      :  %s\n" % result_to_string(best_result)
        return [best_result,possibilities]  if [OUTPUT_LOSS, OUTPUT_TIMEOUT].include?( best_result )


        (1..8).each do |try|
          next  if column_full?( situation_to_be_solved, try )

          result      = reverse_result( prepare_expect_config_and_solve( out, situation_to_be_solved + try.to_s ) )
          out << sprintf( result )


          possibilities[result] << try
        end #each do

        printf( "\n" )
        return [best_result, possibilities]
      end #solve_situation

      def reverse_result( result )
        return OUTPUT_LOSS        if OUTPUT_WIN         == result
        return OUTPUT_WIN         if OUTPUT_LOSS        == result
        return OUTPUT_MAYBE_LOSS  if OUTPUT_MAYBE_WIN   == result
        return OUTPUT_MAYBE_WIN   if OUTPUT_MAYBE_LOSS  == result
        return result
      end #reverse_result
      def result_to_string( result )
        case result
          when OUTPUT_WIN;        return 'Win'
          when OUTPUT_DRAW;       return 'Draw'
          when OUTPUT_LOSS;       return 'Loss'
          when OUTPUT_MAYBE_WIN;  return 'Win or Draw'
          when OUTPUT_MAYBE_LOSS; return 'Loss or Draw'
          # case OUTPUT_TIMEOUT
          else;               return 'Unknown'
        end #case
      end #result_to_string




      unless situation_to_be_solved
        situation_to_be_solved  = analyze_brettspielnetz_game( out, game_number, website_type )
      end #unless

      #printf( "Current situation:  %s\n", situation_to_be_solved.chars.map{|col| (col.to_i+96).chr}.join(', ') )
      out << sprintf( "Next player      :  %s (%s)\n", 0 == situation_to_be_solved.length % 2  ?  'Yellow'  :  'Red', situation_to_be_solved.length % 2 + 1 )


      best_result, possibilities  = solve_situation( out, situation_to_be_solved )

      poss_strings  = Hash.new {|h,k| h[k] = []}
      possibilities.map do |output, options|
        poss_strings[output]  = options.map{|e| (64 + e).chr  +  ([OUTPUT_MAYBE_WIN, OUTPUT_MAYBE_LOSS].include?(output)  ?  '(?)'  :  '')}
      end
      poss_wins     = (poss_strings[OUTPUT_WIN]  +  poss_strings[OUTPUT_MAYBE_WIN]).sort.join(', ')
      poss_draws    = (poss_strings[OUTPUT_DRAW]  +  poss_strings[OUTPUT_MAYBE_LOSS]).sort.join(', ')
      poss_losses   = (poss_strings[OUTPUT_LOSS]).sort.join(', ')



      out << sprintf( <<-Rayo,

===========================================
Best Result    :  %s
Possibilities
%s%s%s

<>

                      Rayo
                      result_to_string(best_result),
                      poss_wins.empty?    ?  ''  :  "  Wins           :  %s\n"  %  poss_wins,
                      poss_draws.empty?   ?  ''  :  "  Draws          :  %s\n"  %  poss_draws,
                      poss_losses.empty?  ?  ''  :  "  Losses         :  %s\n"  %  poss_losses,
      )

      out << "\n</code>"

    rescue => ex
      out << "\n</code>\n"
      out << '<h2>%s!<h2>' % ex.class
      out << "\n<code>\n"
      out << ex.inspect
      out << ex.backtrace
      out << "\n</code>\n"
    end
  end #stream
end #check_game







get '/' do
  content_type 'text/html'
  File.read( 'index.html' )
end
post '/check-game', &check_game
