module XeroGateway
  class Item

    attr_accessor :code, :name, :description, :sales_details

    def initialize(params = {})
      params.each do |k,v|
        self.send("#{k}=", v)
      end
    end

    def to_xml(b = Builder::XmlMarkup.new)
      b.Item {
        b.Code code
        b.Name name
        b.Description description
        b.SalesDetails {
          b.UnitPrice sales_details[:unit_price]
          b.AccountCode sales_details[:account_code]
        }
      }
    end

    def self.from_xml(item_element)
      item = Item.new
      item.sales_details = {}
      item_element.children.each do |element|
        case(element.name)
          when "Code" then item.code = element.text
          when "Name" then item.name = element.text
          when "Description" then item.description = element.text
          when "SalesDetails" then element.children.each do |e|
            item.sales_details[e.name.underscore.to_sym] = e.text
          end
        end
      end
      item
    end

  end
end
