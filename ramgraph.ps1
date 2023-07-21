# Add required assemblies
Add-Type -AssemblyName PresentationFramework,System.Windows.Forms,System.Windows.Forms.DataVisualization
 
# Create WPF window
[xml]$xaml = @"
<Window          xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"         xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"         Title="Chart Example" Height="350" Width="420">
    <Grid>
        <Image x:Name="image" HorizontalAlignment="Left" Height="auto" VerticalAlignment="Top" Width="auto"/>
    </Grid>
</Window>
 
"@
 
# Add window and it's named elements to a hash table
$script:hash = @{}
$hash.Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
    $hash.$($_.Name) = $hash.Window.FindName($_.Name)
}
 
# Function to create a Windows Forms pie chart
# Modified from https://www.simple-talk.com/sysadmin/powershell/building-a-daily-systems-report-email-with-powershell/
Function Create-PieChart() {
    param([hashtable]$Params)
 
    #Create our chart object
    $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
    $Chart.Width = 430
    $Chart.Height = 330
    $Chart.Left = 10
    $Chart.Top = 10
 
    #Create a chartarea to draw on and add this to the chart
    $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $Chart.ChartAreas.Add($ChartArea)
    [void]$Chart.Series.Add("Data") 
 
    #Add a datapoint for each value specified in the parameter hash table
    $Params.GetEnumerator() | foreach {
        $datapoint = new-object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $_.Value.Value)
        $datapoint.AxisLabel = "$($_.Value.Header)" + "(" + $($_.Value.Value) + " GB)"
        $Chart.Series["Data"].Points.Add($datapoint)
    }
 
    $Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
    $Chart.Series["Data"]["PieLabelStyle"] = "Outside"
    $Chart.Series["Data"]["PieLineColor"] = "Black"
    $Chart.Series["Data"]["PieDrawingStyle"] = "Concave"
    ($Chart.Series["Data"].Points.FindMaxByValue())["Exploded"] = $true
 
    #Set the title of the Chart
    $Title = new-object System.Windows.Forms.DataVisualization.Charting.Title
    $Chart.Titles.Add($Title)
    $Chart.Titles[0].Text = "RAM Usage Chart ($($env:COMPUTERNAME))"
 
    #Save the chart to a memory stream, then to the hash table as a byte array
    $Stream = New-Object System.IO.MemoryStream
    $Chart.SaveImage($Stream,"png")
    $Hash.Stream = $Stream.GetBuffer()
    $Stream.Dispose()
}
 
# Add an event to display the chart when the window is opened
$hash.Window.Add_ContentRendered({
    # Create a hash table to store values
    $Params = @{}
    # Get local RAM usage from WMI
    $RAM = (Get-CimInstance -ClassName Win32_OperatingSystem -Property TotalVisibleMemorySize,FreePhysicalMemory)
    # Add Free RAM to a hash table
    $Params.FreeRam = @{}
    $Params.FreeRam.Header = "Free RAM"
    $Params.FreeRam.Value = [math]::Round(($RAM.FreePhysicalMemory / 1MB),2)
    # Add used RAM to a hash table
    $Params.UsedRam = @{}
    $Params.UsedRam.Header = "Used RAM"
    $Params.UsedRam.Value = [math]::Round((($RAM.TotalVisibleMemorySize / 1MB) - ($RAM.FreePhysicalMemory / 1MB)),2)
    # Create the Chart
    Create-PieChart $Params
    # Set the image source
    $Hash.image.Source = $hash.Stream
})
 
# Display window
$null = $hash.Window.ShowDialog()
