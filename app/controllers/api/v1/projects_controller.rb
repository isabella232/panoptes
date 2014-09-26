class Api::V1::ProjectsController < Api::ApiController
  include JsonApiController
  
  doorkeeper_for :update, :create, :delete, scopes: [:project]
  resource_actions :update, :create, :destroy

  alias_method :project, :controlled_resource
  
  allowed_params :create, :description, :display_name, :name,
    :primary_language, links: [owner: polymorphic,
                               workflows: [],
                               subject_sets: []]

  allowed_params :update, :description, :display_name,
    links: [workflows: [], subject_sets: []]
  
  def show
    render json_api: serializer.resource(params,
                                         visible_scope,
                                         languages: current_languages,
                                         fields: ['title',
                                                  'description',
                                                  'example_strings',
                                                  'pages'])
  end

  def index
    add_owner_ids_filter_param!
    render json_api: serializer.page(params,
                                     visible_scope,
                                     languages: current_languages,
                                     fields: ['title', 'description'])
  end

  private

  def add_owner_ids_filter_param!
    owner_filter = params.delete(:owner)
    owner_ids = OwnerName.where(name: owner_filter).map(&:resource_id).join(",")
    params.merge!({ owner_ids: owner_ids }) unless owner_ids.blank?
  end

  def create_response(project)
    serializer.resource(project,
                        nil,
                        languages: [ params[:projects][:primary_language] ],
                        fields: ['title', 'description'] )
  end

  def content_from_params(params)
    title, language = params.values_at(:display_name, :primary_language)
    description = params.delete(:description)
    { description: description,
      title: title,
      language: language }.select { |k,v| !!v } 
  end

  def build_resource_for_create(create_params)
    content_params = content_from_params(create_params)
    
    create_params[:links] ||= Hash.new
    create_params[:links][:owner] = owner || api_user.user

    project = super(create_params)
    project.project_contents.build(**content_params)
    project
  end

  def build_resource_for_update(update_params)
    content_params = content_from_params(update_params)
    super(update_params)
    project.primary_content.update_attributes(content_params)
  end

  def new_items(relation, value)
    super(relation, value).map(&:dup)
  end
end 
