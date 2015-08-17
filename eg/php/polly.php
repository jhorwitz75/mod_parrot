<?php
    echo "<h1>Polly (PHP/Plumhead)</h1>\n";
    $say = $_GET['say'];
    if ($say) {
        echo "SQUAWK!  Polly says ";
        echo $say;
        echo "!<p>\n";
    }
    echo "Reload with an argument called 'say' and Polly will repeat it.\n";
?>
