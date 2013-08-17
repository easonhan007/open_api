module ModelInterface
	def return_fields
		self.class.column_names
	end

	def json_output
		result = {}
		return_fields.each { |f| result[f.to_sym] = self[f] }
		result.to_json
	end
end
