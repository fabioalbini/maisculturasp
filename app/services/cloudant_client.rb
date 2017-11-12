class CloudantClient
  attr_reader :client

  def initialize(database='chat_db')
    credentials = {
      :username => 'USERNAME',
      :password => 'PASSWORD',
      :database => database
    }
    @client = Cloudant::Client.new(credentials)
  end

  def self.populate
    next_record = 1
    per_page = 10

    cc = CloudantClient.new('eventos_api')
    cc.client.create_db('eventos_api')
    cc.client.create_index({index: {}, type: 'text', name: 'test_index'})

    (1..15).each do |page|
      puts "Page: #{page}"
      response = CatracaLivre.fetch_events(Time.now, Time.now + 20.days, {limit: per_page, start: next_record})
      response.each do |event|
        current_doc = cc.client.query({'selector' => {'id' => event[:id]}})['docs'].first
        puts "Event: #{event[:id]}"
        if current_doc.present?
          puts "Updating #{current_doc['_id']}..."
          cc.client.update_doc(current_doc.merge(event))
        else
          puts 'Creating...'
          puts cc.client.create(event)
        end
      end

      break if response.empty?
      next_record += per_page
    end
  end
end
