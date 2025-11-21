CREATE DATABASE IF NOT EXISTS Team10_Deliverable4;
USE Team10_Deliverable4;
-- DROP DATABASE Team10_Deliverable4;

DROP VIEW IF EXISTS FlightStatuses;
DROP TABLE IF EXISTS UserFlights;
DROP TABLE IF EXISTS CustomerRewards;
DROP TABLE IF EXISTS Customers;
DROP TABLE IF EXISTS Employees;
DROP TABLE IF EXISTS Flights;
DROP TABLE IF EXISTS Rewards;
DROP TABLE IF EXISTS TicketPrices;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS EmployeePositions;
DROP TRIGGER IF EXISTS block_second_ceo;
DROP PROCEDURE IF EXISTS purchaseTicket;

CREATE TABLE Users (
    userID INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(64) NOT NULL,
    dateCreated DATETIME DEFAULT CURRENT_TIMESTAMP,
    type ENUM("Customer", "Staff") NOT NULL DEFAULT "Customer"
);

CREATE TABLE Customers (
    userID INT PRIMARY KEY,
    totalMiles INT NOT NULL DEFAULT 0,
    points INT NOT NULL DEFAULT 0,
    FOREIGN KEY (userID) REFERENCES Users(userID)
);

CREATE TABLE Employees (
    userID INT PRIMARY KEY,
    salary DECIMAL(10, 2),
    startDate DATETIME,
    position VARCHAR(30),
    FOREIGN KEY (userID) REFERENCES Users(userID)
);

CREATE TABLE EmployeePositions (
    id INT PRIMARY KEY,
    position VARCHAR(30) NOT NULL
);

CREATE TABLE Flights (
    flightID INT PRIMARY KEY,
    status ENUM("Delayed", "Cancelled", "On Time", "In-flight") NOT NULL DEFAULT "On Time",
    arrival DATETIME,
    departure DATETIME,
    airline VARCHAR(20) NOT NULL,
    model VARCHAR(20) NOT NULL,
    toLocation VARCHAR(20) NOT NULL,
    distanceTraveled INT
);

CREATE TABLE Rewards (
    rewardID INT PRIMARY KEY,
    requiredPoints INT NOT NULL,
    rewardTier INT NOT NULL
);

CREATE TABLE TicketPrices (
    ticketID INT PRIMARY KEY NOT NULL,
    firstClassPrice DECIMAL(10, 2),
    businessClassPrice DECIMAL(10, 2),
    economyPrice DECIMAL(10, 2)
);

CREATE TABLE UserFlights (
    userID INT NOT NULL,
    flightID INT NOT NULL,
    ticketID INT NOT NULL,
    PRIMARY KEY (userID, flightID),
    FOREIGN KEY (userID) REFERENCES Users(userID),
    FOREIGN KEY (flightID) REFERENCES Flights(flightID),
    FOREIGN KEY (ticketID) REFERENCES TicketPrices(ticketID)
);

-- relationship between rewards and customers
-- (customers have rewards, but customers need a reward tier - l3 normalization requires this to be its own table so to not have a transitive dependency through miles travelled)
CREATE TABLE CustomerRewards (
    userID INT NOT NULL,
    rewardID INT NOT NULL,
    rewardTier INT NOT NULL,
    PRIMARY KEY (userID, rewardID),
    FOREIGN KEY (userID) REFERENCES Users(userID),
    FOREIGN KEY (rewardID) REFERENCES Rewards(rewardID)
);

CREATE VIEW FlightStatuses AS 
SELECT flightID, status FROM Flights;

-- Procedure [purchaseTicket]:
-- (i) Obtaining a seat price (seat class) for a ticket and converting it into reward points.
-- (ii) To insert a new booking into userflights using the customer info (user, flight, ticket id)
-- (iii) Also, to update the customer's total points after travelling 

DELIMITER //

CREATE PROCEDURE purchaseTicket(
    IN input_userID INT,
    IN input_flightID INT,
    IN input_ticketID INT
)
BEGIN
    DECLARE earned_points INT;

    -- Calculating the reward points from the economy price
    SELECT FLOOR(economyPrice/10)
    INTO earned_points
    FROM TicketPrices
    WHERE ticketID = input_ticketID;

    -- Inserting a new booking for this user 
    INSERT INTO UserFlights(userID, flightID, ticketID)
    VALUES (input_userID, input_flightID, input_ticketID);

    -- Adding the earned reward points into the user's total 
    UPDATE Customers
    SET points = points + earned_points
    WHERE userID = input_userID;
END // 

DELIMITER ;

-- Function [avgPrice]:
-- Just returning the average price of a flight based off the type of seat the user takes (economy, business, first)

DELIMITER //

CREATE FUNCTION avgPrice(input_ticketID INT)
RETURNS DECIMAL(10, 2)
BEGIN
    DECLARE resulted_price DECIMAL(10, 2);

    SELECT (firstClassPrice + businessClassPrice + economyPrice) / 3
    INTO resulted_price
    FROM TicketPrices 
    WHERE ticketID = input_ticketID;

    RETURN resulted_price;
END // 

DELIMITER ; 
DELIMITER //

DROP TRIGGER IF EXISTS enforce_single_CEO_before_insert;

CREATE TRIGGER enforce_single_CEO_before_insert
BEFORE INSERT ON Employees
FOR EACH ROW
BEGIN
    DECLARE existingCEO INT;

    -- Check if there is an existing CEO
    IF NEW.position = 'CEO' THEN
        SELECT userID INTO existingCEO
        FROM Employees
        WHERE position = 'CEO'
        LIMIT 1;

        -- If a CEO exists, demote them
        IF existingCEO IS NOT NULL THEN
            UPDATE Employees
            SET position = 'Janitor'
            WHERE userID = existingCEO;
        END IF;
    END IF;
END//

DELIMITER ;

DELIMITER //
CREATE TRIGGER block_second_ceo
BEFORE INSERT ON Employees
FOR EACH ROW
BEGIN
    IF NEW.position = 'CEO' AND EXISTS (
        SELECT 1 FROM Employees WHERE position = 'CEO'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Only one CEO allowed.';
    END IF;
END//
DELIMITER ;
