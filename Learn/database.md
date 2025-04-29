CREATE TABLE all_products (
    id SERIAL PRIMARY KEY, -- Assuming 'id' is a unique identifier
    created_at TIMESTAMP NOT NULL, -- Stores the creation time
    name VARCHAR(255) NOT NULL, -- Product name with a max length of 255
    uprices Text(10, 2) NOT NULL, -- Prices with up to 10 digits and 2 decimal places
    image TEXT, -- URL or path for the product image
    discount int2, -- Discount in percentage or a numeric value
    description TEXT, -- Detailed description of the product
    category_1 VARCHAR(255), -- First category (optional length adjustment)
    category_2 VARCHAR(255), -- Second category (optional length adjustment)
    popular_product bool,
    matching_words Text
);


