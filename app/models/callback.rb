# frozen_string_literal: true

class Callback < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  validates :active, inclusion: { in: [ true, false ] }
  validates :timeout_in_seconds, numericality: { greater_than: 0, less_than_or_equal_to: 20, only_integer: true },
 allow_nil: true

  validates :example_response, presence: true
  validates :request_schema, presence: true
  validates :response_schema, presence: true

  validate :validate_json_schemas
  validate :validate_active_requirements

  scope :active, -> { where(active: true) }

private

  def validate_json_schemas
    validate_json_field(:example_response, "example_response")
    validate_json_field(:request_schema, "request_schema")
    validate_json_field(:response_schema, "response_schema")
  end

  def validate_json_field(field, field_name)
    return if send(field).blank?

    unless send(field).is_a?(Hash)
      errors.add(field_name.to_sym, "must be a valid JSON object")
    end
  rescue JSON::ParserError
    errors.add(field_name.to_sym, "must be a valid JSON object")
  end

  def validate_active_requirements
    return unless active?

    if url.blank?
      errors.add(:active, "cannot be enabled without a URL")
    end

    if timeout_in_seconds.blank?
      errors.add(:active, "cannot be enabled without a timeout")
    end
  end
end
