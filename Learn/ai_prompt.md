

1. Essential AI prompts for developers

    1. @workspace propose a file/folder structure for this project. Ask me a series of yes/no questions that will help you provide a better recommendation 
    2. what are a few different ways that i can implement this db connection logic. give me that pros and cons of each strategy. #file:db.ts
    3. help me refactor the code in #file:vehiclesService.ts. Go one step at a time do not move to the next step until i give the keyword "next". Begin.
    4. your a skill instructor who makes complex topics easy to understand. you come up with fun excercise so that your students can learn by doing. your goal is to teach students to be proficient with regex. move one step at a time and wait for the student to provide the correct answer before you move on to the next concept. if the student provide the wrong answer, give them a hint. begin 
    ++


2. add responsiveness to the pagination footer to handle both small and larger screen sizes properly



3. You are a skilled developer integrating an inbuilt relational database (RDBMS) into a Flutter project. Your task is to implement a SQLite database, create a button in the UI labeled "Sync All Products table," and define its functionality as follows:

    1. **Database Integration**:
    - Use the `sqflite` and `path` packages to implement SQLite.
    - Ensure the database is initialized when the application starts.

    2. **Button Creation**:
    - Design a button in the UI labeled "Sync All Products table" using Flutter widgets.
    - The button should have an `onPressed` function.

    3. **On Button Click**:
    - If the database does not already contain a table named `data_table`:
        - Create the table dynamically.
    - Insert predefined data into the table (e.g., an `id` column and a `value` column).

    4. **Code Structure**:
    - Ensure clean and modular code.
    - Use async methods to handle database operations.
    - Add error handling for database initialization and operations.

    5. database does not already contain a table named `all_products`. If the table doesn't exist:
    - Create the table dynamically.
    - Insert data fetched from an existing Supabase `all_products` table into the newly created SQLite table.

    6. Additionally:
    - Write all backend logic, including database initialization and data insertion, in a separate Dart file to maintain clean project organization.
    - Ensure proper error handling for database operations and Supabase data fetching.
    - Use modular, reusable methods to fetch, create, and insert data.
    Provide the full implementation in Flutter, including backend logic and the UI with a button labeled "Sync All Product table."


    Write the full implementation in Flutter, including UI and backend logic.