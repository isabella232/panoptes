class Api::V1::SetMemberSubjectsController < Api::ApiController
  doorkeeper_for :create, :update, :destroy, scopes: [:project]
  resource_actions :default
  schema_type :strong_params

  allowed_params :create, :priority, :state, links: [:subject, :subject_set, retired_workflows: []]
  allowed_params :update, :priority, links: [retired_workflows: []]
end
