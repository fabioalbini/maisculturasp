class CatracaLivre
  SHORTEN_URL=true

  def self.fetch_events(data_inicial, data_final, additional_options={})
    time_range = "#{format_time_to_solr(data_inicial)}%20TO%20#{format_time_to_solr(data_final)}"
    request_uri = "https://api.catracalivre.com.br/select/?q=place_city:Sao\%20Paulo+AND+event_datetime:[#{time_range}]"

    if additional_options[:type].present?
      request_uri += "+AND+place_type:#{I18n.transliterate(additional_options[:type]).sub(' ', '%20')}"
    end

    request_uri += "&row=#{additional_options[:limit]}" if additional_options[:limit].present?
    request_uri += "&start=#{additional_options[:start]}" if additional_options[:start].present?

    preco_minimo = additional_options[:preco_minimo].present? ? additional_options[:preco_minimo] : 0
    preco_maximo = additional_options[:preco_maximo].present? ? additional_options[:preco_maximo] : 10_000
    request_uri += "+AND+event_price_numeric:[#{preco_minimo}%20TO%20#{preco_maximo}]"

    puts "Request URI: '#{request_uri}'"
    response = RestClient.get request_uri, {:accept => :xml, :content_type => :xml}

    parsed_response = Nokogiri::XML(response.body)

    result = parsed_response.search('result').first
    eventos_tratados = []

    return [] if result.attributes['numFound'].to_s.to_i.zero?
    result.search('doc').each do |evento_raw|
      eventos_tratados.push(tratar_evento(evento_raw, data_inicial, data_final))
    end
    eventos_tratados
  end

  def self.format_time_to_solr(time)
    time.strftime('%Y-%m-%dT%H:%M:%SZ')
  end

  def self.tratar_evento(doc, data_inicial, data_final)
    info_evento = {
      descricao: doc.search('str[@name="post_title"]').text,
      id: doc.search('int[@name="post_id"]').text.to_i
    }

    info_evento[:data] = []
    doc.search('arr[@name="event_datetime"]').first.search('date').each do |data_str|
      data = Time.parse(data_str)
      info_evento[:data].push(data) if data >= data_inicial && data <= data_final
    end

    info_evento[:tipo] = doc.search('arr[@name="place_type"]').first.search('str').first.text rescue nil
    info_evento[:geolocation] = doc.search('arr[@name="place_geolocation"]').first.search('str').first.text
    info_evento[:cidade] = doc.search('arr[@name="place_city"]').first.search('str').first.text rescue nil
    info_evento[:link] = doc.search('str[@name="post_permalink"]').first.text
    info_evento[:image_thumb] = doc.search('str[@name="post_image_thumbnail"]').first.text
    info_evento[:image_full] = doc.search('str[@name="post_image_full"]').first.text
    info_evento[:price] = doc.search('str[@name="event_price_numeric"]').first.text.gsub(/\,.*?$/,'').to_f rescue 0.0

    place_info = doc.search('arr[@name="event_place"]').first
    if place_info.present? && place_info.search('str').present?
      place_info_json = JSON.parse(place_info.search('str').first.text)
      info_evento[:bairro] = place_info_json['bairro']
      info_evento[:logradouro] = "#{place_info_json['logradouro']}, #{place_info_json['numero']}"
    end

    if SHORTEN_URL
      resp_url = RestClient.post 'https://www.googleapis.com/urlshortener/v1/url?key=KEY', { longUrl: info_evento[:link] }.to_json, { accept: :json, content_type: :json }
      info_evento[:link] = JSON.parse(resp_url.body)['id']
    end

    info_evento
  end
end
