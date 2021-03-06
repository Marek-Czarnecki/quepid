# frozen_string_literal: true

# == Schema Information
#
# Table name: tries
#
#  id             :integer          not null, primary key
#  try_number     :integer
#  query_params   :text(65535)
#  case_id        :integer
#  field_spec     :string(500)
#  search_url     :string(500)
#  name           :string(50)
#  search_engine  :string(50)       default("solr")
#  escape_query   :boolean          default(TRUE)
#  number_of_rows :integer          default(10)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

require 'solr_arg_parser'
require 'es_arg_parser'

class Try < ActiveRecord::Base
  # Scopes
  scope :best, -> { order(id: :desc).first }
  scope :latest, -> { order(try_number: :desc).limit(1).first }

  # Constants
  DEFAULTS = {
    search_engine: 'solr',
    solr:          {
      query_params: 'q=#$query##',
      search_url:   'http://quepid-solr.dev.o19s.com:8985/solr/tmdb/select',
      field_spec:   'id:id title:title',
    },
    es:            {
      query_params: [
        '{',
        '    "query": {',
        '        "match": {',
        '            "_all": "#$query##"',
        '        }',
        '    }',
        '}'
      ].join('\n'),
      search_url:   'http://quepid-elasticsearch.dev.o19s.com:9206/tmdb/_search',
      field_spec:   'id:_id, title:title',
    },
  }.freeze

  # Associations
  belongs_to  :case

  has_many    :curator_variables,
              dependent:  :destroy,
              inverse_of: :try

  # Callbacks
  before_create :set_defaults

  def args
    if 'solr' == search_engine
      solr_args
    elsif 'es' == search_engine
      es_args
    end
  end

  def param
    try_number
  end

  def add_curator_vars vars = {}
    return if vars.blank?

    vars.each do |name, value|
      curator_variables.create(name: name, value: value)
    end
  end

  def curator_vars_map
    Hash[curator_variables.map { |each| [ each.name.to_sym, each.value ] }]
  end

  def solr_args
    SolrArgParser.parse(query_params, curator_vars_map)
  end

  def es_args
    EsArgParser.parse(query_params, curator_vars_map)
  end

  def id_from_field_spec
    # much of this logic is inspired by https://github.com/o19s/splainer-search/blob/master/services/fieldSpecSvc.js

    # rubocop:disable Style/IfUnlessModifier
    # rubocop:disable Style/MultipleComparison
    # rubocop:disable Style/Next
    if 'id' == field_spec || '_id' == field_spec
      return field_spec
    end

    field_specs = field_spec.split
    field_specs.each do |fs|
      if 'id' == fs || '_id' == fs
        return fs
      end

      type_and_field = fs.split(':')
      if 2 == type_and_field.length
        if 'id' == type_and_field[0]
          return type_and_field[1]
        end
      end
    end
    # rubocop:enable Style/IfUnlessModifier
    # rubocop:enable Style/MultipleComparison
    # rubocop:enable Style/Next
  end

  private

  def set_defaults
    self.name = "Try #{try_number}" if name.blank?

    self.search_engine = DEFAULTS[:search_engine] if search_engine.blank?
    self.field_spec    = DEFAULTS[search_engine.to_sym][:field_spec]    if field_spec.blank?
    self.query_params  = DEFAULTS[search_engine.to_sym][:query_params]  if query_params.blank?
    self.search_url    = DEFAULTS[search_engine.to_sym][:search_url]    if search_url.blank?
  end
end
