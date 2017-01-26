class LogFileAnalyzer
  attr_reader :log_file
  
  MATCHERS = [
    ['count_pending_messages', /GET.*count_pending_messages.+bytes=\d{1,}/],
    ['get_messages', /GET.*get_messages.+bytes=\d{1,}/],
    ['get_friends_progress', /GET.*get_friends_progress.+bytes=\d{1,}/],
    ['get_friends_scores', /GET.*get_friends_score.+bytes=\d{1,}/],
    ['post_users', /POST\spath=\/api\/users\/\d{1,}\s.+bytes=\d{1,}/],
    ['get_user', /GET\spath=\/api\/users\/\d{1,}\s.+bytes=\d{1,}/],
  ]

  def initialize(file)
    @log_file = file
    @file_content = []
  end

  def generate_report
    content = read_file.join
    count_url_occurences(content)
    get_response_times(content)
    most_responsive_dyno(content)
  end

  private

  def count_url_occurences(content)
    MATCHERS.each do |matcher|
      url_name = matcher[0]
      url_regex_pattern = matcher[1]
      occurrences = content.scan(url_regex_pattern).size
      puts "#{url_name} occurred #{occurrences}!"
    end
  end

  def get_response_times(content)
    MATCHERS.each do |matcher|
      url_name = matcher[0]
      url_regex_pattern = matcher[1]
      occurrences = content.scan(url_regex_pattern).flatten
      response_times = []
      occurrences.each do |log_string|
        connect_time = log_string.scan(/connect=\d{1,}/)[0].split("=")[1].to_i #parse line connect=9ms service=9ms to get connect value
        service_time = log_string.scan(/service=\d{1,}/)[0].split("=")[1].to_i #parse line connect=9ms service=9ms to get service value
        response_times.push(connect_time + service_time)
      end
      unless response_times.empty?
        mean = response_times.reduce(:+) / response_times.length
        median = response_times.sort[(response_times.length / 2) + 1] # + 1 cause array is zero indexed
        freq = response_times.inject(Hash.new(0)) { |hash,value| hash[value] += 1; hash }
        max = freq.values.max
        mode = freq.select { |k, f| f == max }.keys[0]
        puts "#{url_name}'s mean=#{mean} median=#{median} mode=#{mode}"
      end
    end
  end

  def most_responsive_dyno(content)
    dynos = content.scan(/dyno=web.\d{1,}/)
    freq = dynos.inject(Hash.new(0)) { |hash,value| hash[value] += 1; hash }
    max = freq.values.max
    responsive_dyno = freq.select { |k, f| f == max }.keys[0]
    puts "The most responsive dyno is #{responsive_dyno}"
  end

  def read_file
    file_content = []
    File.foreach(@log_file).with_index do |line, line_number|
      file_content.push(line)
    end
    file_content
  end
end

analyzer = LogFileAnalyzer.new('sample.log')
text = analyzer.generate_report