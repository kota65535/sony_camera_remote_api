# Hash extension for handling API response.
class Hash
  # Get result element.
  def result
    self['result']
  end
  # Get results element.
  def results
    self['results']
  end
  # Get id element.
  def id
    self['id']
  end
  # Get error element.
  def error
    self['error']
  end
end

