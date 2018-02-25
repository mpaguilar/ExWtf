defprotocol Model.Ndxr do
  def from(item)
  def upsert(item, parent)
end
