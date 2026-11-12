/*
 * PayEdge Digital Bank: MongoDB transaction generator
 * MIT 8103 | Portfolio 4: NoSQL and Advanced Data Models
 *
 * I wrote this program to create 800 realistic transaction documents for the Atlas 'transactions' collection.
 * A fixed random seed means running it again produces identical data.
 *
 * Design notes:
 * - Account numbers match the PayEdge sample accounts, so the documents link to the customers collection.
 * - Deposits have no fromAccount and withdrawals have no toAccount. The fields are simply absent, which a document database allows.
 * - Optional fields (device, location, fees) appear on only some documents. This demonstrates the flexible schema that PostgreSQL
 *   would need an ALTER TABLE migration to match.
 */
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Random;

public class GenerateTransactions {

    static final int TOTAL = 800;
    static final int DAYS_BACK = 90;

    // {account number, customerId} for the seven PayEdge accounts
    static final String[][] ACCOUNTS = {
            {"8077343538", "1"}, {"0077343538", "1"},
            {"9144577709", "2"},
            {"7034567890", "3"},
            {"8155609905", "4"},
            {"8055788012", "5"}, {"0055788012", "5"}
    };

    // Accounts at other banks, used as transfer destinations
    static final String[][] EXTERNAL = {
            {"2034567890", "GTBank"}, {"3045678912", "Access Bank"}
    };

    // About 80% SUCCESS, 10% PENDING, 10% FAILED
    static final String[] STATUSES = {
            "SUCCESS", "SUCCESS", "SUCCESS", "SUCCESS", "SUCCESS",
            "SUCCESS", "SUCCESS", "SUCCESS", "PENDING", "FAILED"
    };
    static final String[] CHANNELS = {"mobile", "web", "ussd", "atm"};
    static final String[] CITIES = {"Lagos", "Abuja", "Kaduna", "Enugu", "Port Harcourt"};
    static final String[] NARRATIONS = {
            "Rent payment", "School fees", "Electricity bill", "Groceries",
            "Loan repayment", "Salary", "Transport", "Family support", "Airtime"
    };

    public static void main(String[] args) throws IOException {
        Random rnd = new Random(42);
        ZonedDateTime anchor = ZonedDateTime.of(2026, 11, 12, 0, 0, 0, 0, ZoneOffset.UTC);
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss'Z'");

        StringBuilder out = new StringBuilder("[");

        for (int i = 1; i <= TOTAL; i++) {
            int roll = rnd.nextInt(100);
            String type = roll < 70 ? "TRANSFER" : roll < 85 ? "DEPOSIT" : "WITHDRAWAL";

            double amount = Math.round((500 + rnd.nextDouble() * 249500) * 100) / 100.0;
            ZonedDateTime when = anchor.minusMinutes(rnd.nextInt(DAYS_BACK * 24 * 60 + 1));

            List<String> f = new ArrayList<>();
            f.add(text("reference", String.format("MDB-TXN-%05d", i)));
            f.add(text("type", type));
            f.add("\"amount\":" + String.format(Locale.US, "%.2f", amount));
            f.add(text("currency", "NGN"));
            f.add(text("status", pick(rnd, STATUSES)));
            f.add("\"timestamp\":{\"$date\":\"" + when.format(fmt) + "\"}");
            f.add(text("channel", pick(rnd, CHANNELS)));
            f.add(text("narration", pick(rnd, NARRATIONS)));

            if (type.equals("TRANSFER")) {
                String[] sender = ACCOUNTS[rnd.nextInt(ACCOUNTS.length)];
                f.add(text("fromAccount", sender[0]));
                f.add("\"customerId\":" + sender[1]);
                if (rnd.nextDouble() < 0.20) {                 // transfer to another bank
                    String[] ext = EXTERNAL[rnd.nextInt(EXTERNAL.length)];
                    f.add(text("toAccount", ext[0]));
                    f.add(text("toBank", ext[1]));
                } else {                                       // transfer inside PayEdge
                    String[] receiver;
                    do {
                        receiver = ACCOUNTS[rnd.nextInt(ACCOUNTS.length)];
                    } while (receiver[0].equals(sender[0]));
                    f.add(text("toAccount", receiver[0]));
                }
            } else if (type.equals("DEPOSIT")) {
                String[] receiver = ACCOUNTS[rnd.nextInt(ACCOUNTS.length)];
                f.add(text("toAccount", receiver[0]));
                f.add("\"customerId\":" + receiver[1]);
            } else {                                           // WITHDRAWAL
                String[] sender = ACCOUNTS[rnd.nextInt(ACCOUNTS.length)];
                f.add(text("fromAccount", sender[0]));
                f.add("\"customerId\":" + sender[1]);
            }

            // Optional fields: present on some documents only (flexible schema)
            if (rnd.nextDouble() < 0.40) {
                String deviceId = String.format("DEV-%03d", 1 + rnd.nextInt(40));
                String ip = "41.78." + rnd.nextInt(256) + "." + (1 + rnd.nextInt(254));
                f.add("\"device\":{\"deviceId\":\"" + deviceId + "\",\"ip\":\"" + ip + "\"}");
                f.add(text("location", pick(rnd, CITIES)));
            }
            if (rnd.nextDouble() < 0.15) {
                f.add("\"fees\":{\"stampDuty\":50}");
            }

            out.append(i > 1 ? "," : "").append("{").append(String.join(",", f)).append("}");
        }

        out.append("]");
        Files.writeString(Path.of("transactions.json"), out.toString(), StandardCharsets.UTF_8);
        System.out.println("Wrote " + TOTAL + " documents to transactions.json");
    }

    // Builds "key":"value". Safe here because none of my values contain quotes.
    static String text(String key, String value) {
        return "\"" + key + "\":\"" + value + "\"";
    }

    static String pick(Random rnd, String[] options) {
        return options[rnd.nextInt(options.length)];
    }
}