class EventsController < ApplicationController
  def index
    data_inicial = params[:data_inicial].present? ? Time.parse(params[:data_inicial]) : Time.now
    data_final = params[:data_final].present? ? Time.parse(params[:data_final]) : Time.now + 48.hours

    additional_options = {}
    additional_options.merge!(type: params[:type]) if params[:type].present?
    additional_options.merge!(limit: params[:limit]) if params[:limit].present?
    additional_options.merge!(preco_minimo: params[:preco_minimo]) if params[:preco_minimo].present?
    additional_options.merge!(preco_maximo: params[:preco_maximo]) if params[:preco_maximo].present?

    remember_request

    @eventos = CatracaLivre.fetch_events(data_inicial, data_final, additional_options)

    if params[:type] =~ /cinema/i
      @eventos = [] if params[:genero].present?
      @eventos = Ingresso.fetch_movies(params[:genero], {}) + @eventos
    end

    respond_to do |format|
      format.json { render json: { eventos: @eventos[0..4] }.to_json }
    end
  end

  private

  def remember_request
    request_info = {
      week_day: Date.today.wday,
      preco_maximo: params[:preco_minimo],
      type: params[:type]
    }

    cc = CloudantClient.new('requests')
    cc.client.create(request_info)
  end

  def place_type
    case params[:type]
    when /cinema/i then 'cinema'
    when /teatro/i then 'teatro'
    else
      params[:type]
    end
  end
end
