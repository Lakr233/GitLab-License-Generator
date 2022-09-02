module Gitlab
  class License
    module Boundary
      BOUNDARY_START  = /(\A|\r?\n)-*BEGIN .+? LICENSE-*\r?\n/.freeze
      BOUNDARY_END    = /\r?\n-*END .+? LICENSE-*(\r?\n|\z)/.freeze

      class << self
        def add_boundary(data, product_name)
          data = remove_boundary(data)

          product_name.upcase!

          pad = lambda do |message, width|
            total_padding = [width - message.length, 0].max

            padding = total_padding / 2.0
            [
              '-' * padding.ceil,
              message,
              '-' * padding.floor
            ].join
          end

          [
            pad.call("BEGIN #{product_name} LICENSE", 60),
            data.strip,
            pad.call("END #{product_name} LICENSE", 60)
          ].join("\n")
        end

        def remove_boundary(data)
          after_boundary  = data.split(BOUNDARY_START).last
          in_boundary     = after_boundary.split(BOUNDARY_END).first

          in_boundary
        end
      end
    end
  end
end
