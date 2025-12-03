--
-- DDL
--

-- DROP DATABASE IF EXISTS Team10_Deliverable4;
CREATE DATABASE IF NOT EXISTS Team10_Deliverable4;
USE Team10_Deliverable4;

DROP TABLE IF EXISTS UserFlights;
DROP TABLE IF EXISTS TicketPrices;
DROP TABLE IF EXISTS CustomerRewards;
DROP TABLE IF EXISTS Customers;
DROP TABLE IF EXISTS Employees;
DROP TABLE IF EXISTS Flights;
DROP TABLE IF EXISTS Rewards;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS EmployeePositions;
DROP VIEW IF EXISTS FlightStatuses;
DROP VIEW IF EXISTS EmployeeView;
DROP PROCEDURE IF EXISTS purchaseTicket;
DROP FUNCTION IF EXISTS avgPrice;
DROP TRIGGER IF EXISTS blockSecondCeo;
DROP TRIGGER IF EXISTS checkPriceTier;
DROP TRIGGER IF EXISTS validatePositionBeforeInsert;

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
    rewardTier INT NOT NULL,
    rewardDescription VARCHAR(200) NOT NULL DEFAULT ''
);

CREATE TABLE TicketPrices (
    ticketID INT PRIMARY KEY NOT NULL,
    firstClassPrice DECIMAL(10, 2),
    businessClassPrice DECIMAL(10, 2),
    economyPrice DECIMAL(10, 2),
    flightID INT NOT NULL,
    FOREIGN KEY (flightID) REFERENCES Flights(flightID)
);

CREATE TABLE UserFlights (
    userID INT NOT NULL,
    flightID INT NOT NULL,
    ticketID INT NOT NULL,
    class ENUM("First Class", "Business Class", "Economy") NOT NULL DEFAULT "Economy",
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

-- Views 
CREATE VIEW FlightStatuses AS 
SELECT flightID, status FROM Flights;

-- We don't use this one... just kept around for points.
CREATE VIEW EmployeeView AS
SELECT e.userID, u.name AS employeeName, e.position
FROM Employees e
JOIN Users u ON e.userID = u.userID;


-- Procedure [purchaseTicket]:
-- (i) Obtaining a seat price (seat class) for a ticket and converting it into reward points.
-- (ii) To insert a new booking into userflights using the customer info (user, flight, ticket id)
-- (iii) Also, to update the customer's total points after travelling 
DELIMITER //
CREATE PROCEDURE purchaseTicket(
    IN input_userID INT,
    IN input_flightID INT,
    IN input_ticketID INT,
    IN input_class ENUM("First Class", "Business Class", "Economy")
)
BEGIN
    DECLARE earned_points INT DEFAULT 0;
    DECLARE success BOOLEAN DEFAULT FALSE;

    -- Calculating the points
    SELECT FLOOR(economyPrice / 10)
    INTO earned_points
    FROM TicketPrices
    WHERE ticketID = input_ticketID;

    -- Inserting the  booking WITH CLASS
    INSERT INTO UserFlights(userID, flightID, ticketID, class)
    VALUES (input_userID, input_flightID, input_ticketID, input_class);

    -- Updating the points
    UPDATE Customers
    SET points = points + earned_points
    WHERE userID = input_userID;

    SET success = TRUE;
    SELECT success AS purchaseSuccess;

END //
DELIMITER ;


-- Function [avgPrice]:
-- Just returning the average price of a flight based off the type of seat the user takes (economy, business, first)
DELIMITER //
CREATE FUNCTION avgPrice(
    input_ticketID INT
)
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

-- The three triggers 

DELIMITER //
CREATE TRIGGER blockSecondCeo
BEFORE INSERT ON Employees
FOR EACH ROW
BEGIN
    IF NEW.position = 'CEO' AND EXISTS (
        SELECT 1 FROM Employees WHERE position = 'CEO'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only one CEO allowed.';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER checkPriceTier
AFTER INSERT ON TicketPrices
FOR EACH ROW
BEGIN
	IF NEW.firstClassPrice < NEW.businessClassPrice OR 
		NEW.firstClassPrice < NEW.economyPrice OR 
        NEW.businessClassPrice < NEW.economyPrice
	THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid order of prices! Economy should be the least expensive, first class the most, and business class in the middle.';
	END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER validatePositionBeforeInsert
BEFORE INSERT ON Employees
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM EmployeePositions
        WHERE position = NEW.position
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid position!';
    END IF;
END//
DELIMITER ;

--
-- DML
--

INSERT INTO Users (userID, name, email, password, dateCreated, type) VALUES
-- (1, "Alice",  "alice@example.com",  "hashedpass1",  "2025-01-10 14:23:00"),
(2, "Bob",    "bob@example.com",    "hashedpass2",  "2025-02-02 09:00:00", "Customer"),
(3, "Carol",  "carol@example.com",  "hashedpass3",  "2025-03-12 18:45:00", "Staff"),
(4, "Dave",   "dave@example.com",   "hashedpass4",  "2025-03-15 08:15:00", "Staff"),
(5, "Eve",    "eve@example.com",    "hashedpass5",  "2025-04-01 11:30:00", "Customer"),
(6, "Frank",  "frank@example.com",  "hashedpass6",  "2024-10-30 14:00:00", "Staff"),
(7, "Grace",  "grace@example.com",  "hashedpass7",  "2025-01-11 13:13:13", "Staff"),
(8, "Harold", "harold@example.com", "hashedpass8",  "2025-02-22 02:22:22", "Staff"),
-- (9, "Iman",   "iman@example.com",   "hashedpass9",  "2025-03-30 03:33:33"),
(10, "James", "james@example.com",  "hashedpass10", "2025-10-11 13:00:00", "Customer");

-- demonstration of default values...
INSERT INTO Users (userID, name, email, password, dateCreated) VALUES
(1, "Alice",  "alice@example.com",  "hashedpass1",  "2025-01-10 14:23:00"),
(9, "Iman",   "iman@example.com",   "hashedpass9",  "2025-03-30 03:33:33");

INSERT INTO Customers (userID, totalMiles, points) VALUES
(1,  15200, 300),
(2,  8700,  180),
(5,  22000, 500),
(9,  17000, 100000),
(10, 3000,  200);

INSERT INTO EmployeePositions (id, position) VALUES
(1, "Pilot"),
(2, "Flight Attendant"),
(3, "Janitor"),
(4, "CEO");

INSERT INTO Employees (userID, salary, startDate, position) VALUES
(3, 92000.00,  "2022-05-01 09:00:00", "Pilot"),
(4, 58000.00,  "2020-11-15 09:00:00", "Flight Attendant"),
(6, 120000.00, "2020-01-01 12:00:00", "CEO"),
(7, 80000.00,  "2021-07-04 14:00:00", "Flight Attendant"),
(8, 60000.00,  "2024-10-30 03:30:15", "Janitor");

INSERT INTO Flights (flightID, status, arrival, departure, airline, model, toLocation, distanceTraveled) VALUES
(101, "On Time",   "2025-11-02 20:30:00", "2025-11-02 17:15:00", "SkyJet",    "Boeing 737", 'Denver',800),
(102, "Delayed",   "2025-11-03 12:10:00", "2025-11-03 09:45:00", "AeroWings", "Airbus A320",'Atlanta',850),
(103, "Cancelled", "2025-11-04 19:00:00", "2025-11-04 15:30:00", "SkyJet",    "Boeing 777", 'Los Angeles',1750),
(104, "On Time",   "2025-11-05 22:00:00", "2025-11-05 18:45:00", "AirNova",   "Boeing 787", 'Pheonix',1450),
(105, "On Time",   "2025-11-06 10:15:00", "2025-11-06 06:50:00", "CloudAir",  "Airbus A350",'Dallas',750);

INSERT INTO Rewards (rewardID, requiredPoints, rewardTier) VALUES
(1, 5000,  1),
(2, 15000, 2),
(3, 30000, 3),
(4, 50000, 4),
(5, 75000, 5);

UPDATE Rewards SET rewardDescription = "A free upgrade to first class!" WHERE rewardID = 5;

INSERT INTO TicketPrices (ticketID, firstClassPrice, businessClassPrice, economyPrice, flightID) VALUES
(101, 950.00,  650.00, 250.00, 101),
(102, 850.00,  550.00, 220.00, 101),
(103, 1000.00, 700.00, 280.00, 103),
(104, 1100.00, 750.00, 300.00, 104),
(105, 970.00,  640.00, 240.00, 105);

INSERT INTO UserFlights (userID, flightID, ticketID, class) VALUES
(1, 101, 101, "Economy"),
(2, 101, 102, "Economy"),
(3, 103, 103, "Business Class"),
(3, 105, 104, "First Class"),
(5, 105, 105, "First Class");

INSERT INTO CustomerRewards (userID, rewardID, rewardTier) VALUES
(1,  1, 2),
(2,  2, 1),
(5,  3, 3),
(9,  5, 10),
(10, 4, 1);

-- demo of multiple CEOs not being allowed
-- INSERT INTO Employees (userID, salary, startDate, position)
-- VALUES (10, 150000, "2025-11-21 12:00:00", "CEO");

-- demo of tiers
-- INSERT INTO TicketPrices (ticketID, firstClassPrice, businessClassPrice, economyPrice) VALUES
-- (200, 550.00,  650.00, 250.00);

-- demo of validPositions
-- INSERT INTO Employees (userID, salary, startDate, position) VALUES
-- (33, 92000.00,  "2022-05-01 09:00:00", "Pill Enjoyer");

-- this is also demonstrated in demo 6...
