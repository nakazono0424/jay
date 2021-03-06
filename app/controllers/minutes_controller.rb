class MinutesController < ApplicationController
  before_action :set_minute, only: [:show, :edit, :update, :destroy, :reuse]

  # GET /minutes
  # GET /minutes.json
  def index
    unless params[:search]
      @minutes = Minute.all.order('dtstart DESC')
    else
      @minutes = Query.new(params[:search]).to_scope.order('dtstart DESC')
    end

    if @minutes.class == Array
      @minutes = Kaminari.paginate_array(@minutes).page(params[:page]).per(25)
    else
      @minutes = @minutes.page(params[:page]).per(25)
    end

    respond_to do |format|
      format.html {}
      format.json { render json: @minutes, include: {author: {only: :name}} }
    end
  end

  # GET /minutes/1
  # GET /minutes/1.json
  def show
    respond_to do |format|
      format.html {}
      format.json {}
      format.text {render plain: JayFlavoredMarkdownToPlainTextConverter.new(@minute.cooked_content).content}
    end
  end

  # GET /minutes/new
  def new
    @minute = Minute.new(:author_id => User.current.id)
  end

  # GET /minutes/1/edit
  def edit
  end

  # POST /minutes
  # POST /minutes.json
  def create
    @minute = Minute.new(minute_params)
    @minute.tags = parse_tag_names(params[:tag_names]) if params[:tag_names]

    respond_to do |format|
      if @minute.save
        format.html { redirect_to @minute, notice: 'Minute was successfully created.' }
        format.json { render :show, status: :created, location: @minute }
      else
        format.html { render :new }
        format.json { render json: @minute.errors, status: :unprocessable_entity }
      end
    end
    @payload = pack_payload(@minute)
  end

  # PATCH/PUT /minutes/1
  # PATCH/PUT /minutes/1.json
  def update
    @minute.tags = parse_tag_names(params[:tag_names]) if params[:tag_names]
    respond_to do |format|
      if @minute.update(minute_params)
        format.html { redirect_to @minute, notice: 'Minute was successfully updated.' }
        format.json { render :show, status: :ok, location: @minute }
      else
        format.html { render :edit }
        format.json { render json: @minute.errors, status: :unprocessable_entity }
      end
    end
    @payload = pack_payload(@minute)
  end

  def preview
    send_data ::JayFlavoredMarkdownConverter.new(params[:text]).content, :type => 'text/html', :disposition => 'inline'
  end

  # DELETE /minutes/1
  # DELETE /minutes/1.json
  def destroy
    @minute.destroy
    respond_to do |format|
      format.html { redirect_to minutes_url, notice: 'Minute was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def reuse
    @minute = @minute.dup
  end

  # for ajax search
  def search_by_tag
    unless tag = Tag.find_by(name: params[:tag_name])
      render json: nil
    else
      render json: tag.minutes, include: {author: {only: :name}}
    end
  end

  # POST minutes/comment
  def comment
    url = params[:url]
    comment = params[:comment]
    body = {"body" => comment}

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)

    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    req = Net::HTTP::Post.new(uri.path)
    req['Content-Type'] = "application/json"
    req['Authorization'] = "token "+session[:access_token]
    req.body = JSON.generate({"body" => comment})

    res = http.request(req)
    render json: res.body, status: res.code
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_minute
      @minute = Minute.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def minute_params
      params.require(:minute).permit(:title, :dtstart, :dtend, :location, :author_id, :content, :tag_ids => [] )
    end

    def parse_tag_names(tag_names)
      tag_names.split.map do |tag_name|
        tag = Tag.find_by(name: tag_name)
        tag ? tag : Tag.create(name: tag_name)
        end
    end

    def pack_payload(obj)
      payload = obj.attributes
      payload.merge!({"tags"=>[], "name"=>nil})
      obj.tags.each do |tag|
        payload["tags"] << tag.name
      end
      payload["name"] = obj.author.screen_name
      payload
    end
end
