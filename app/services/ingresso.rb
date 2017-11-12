class Ingresso
  def self.fetch_movies(genre, additional_options={})
    response = RestClient.get 'https://api-content.ingresso.com/v0/templates/nowplaying/1'
    parsed = JSON.parse(response.body)

    selected_movies = []
    parsed.each do |doc|
      next if genre.present? && doc['genres'].find_all { |mg| I18n.transliterate(mg) =~ /#{I18n.transliterate(genre)}/i }.empty?
      next if doc['premiereDate'].present? && (Time.parse(doc['premiereDate']['localDate']) > Time.now + 1.day)
      selected_movies.push(tratar_filme(doc))
    end

    selected_movies
  end

  def self.tratar_filme(doc)
    {
      descricao: doc['title'],
      id: (doc['id'].to_i + 900000),
      data: [Date.today],
      tipo: ['Cinema'],
      geolocation: '',
      cidade: 'São Paulo',
      link: doc['siteURL'],
      price: 25,
      bairro: '',
      logradouro: ''
    }
  end
end
