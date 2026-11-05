class IanaTimezoneValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if TZInfo::Timezone.all_identifiers.include?(value)

    record.errors.add(attribute, "is not a valid IANA timezone")
  end
end
