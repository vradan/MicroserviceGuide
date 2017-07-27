import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.FileReader;

public class CloudWatch {

  public static void main(String args[]) {
    double total;
    double free = 0;
    double buffers = 0;
    double cached = 0;
    Process p;

    try {
      BufferedReader br = new BufferedReader(new FileReader("/proc/meminfo"));
      String line = br.readLine();

      while (line != null) {
        if (line.startsWith("MemTotal")) {
          total = (Float.valueOf(line.replaceAll("\\D+","")))/1024;
        } else if (line.startsWith("MemFree")) {
          free = (Float.valueOf(line.replaceAll("\\D+","")))/1024;
        } else if (line.startsWith("Buffers")) {
          buffers = (Float.valueOf(line.replaceAll("\\D+","")))/1024;
        } else if (line.startsWith("Cached")) {
          cached = (Float.valueOf(line.replaceAll("\\D+","")))/1024;
        }

        line = br.readLine();
      }

      br.close();
    } catch (Exception e) {
      e.printStackTrace();
    }

    int available = (int) (free + buffers + cached);

    String nodeIP = System.getenv("PRIVATE_IPV4");

    executeCommand("aws cloudwatch put-metric-data --namespace Kubernetes --dimension \"AutoScalingGroupName=kube-workers\" --metric-name AvailableMemory --value " + available);

  }

  public static void executeCommand(String cmd) {
    try {
      Process p = Runtime.getRuntime().exec(cmd);

      BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));

      String line = br.readLine();

      while (line != null) {
        System.out.println(line);
        line = br.readLine();
      }
    } catch (Exception e) {
      e.printStackTrace();
    }
  }

}
