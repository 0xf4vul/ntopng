Continuous Traffic Recording
############################

When it comes to troubleshoot a network issue or analyse a security event,
going back in time and drilling down to the packet level could be crucial
to find the exact network activity that caused the problem.
Continuous traffic recording provides a window into network history, that
allows you to retrieve and analyse all the raw traffic in that period of time.

Enabling Traffic Recording
--------------------------

*ntopng* includes support for continuous traffic recording leveraging on
*n2disk*, an optimized traffic recording application part of the *ntop* suite
available on Linux systems. For this reason, in order to be able to enable
this feature in *ntopng*, *n2disk* needs to be installed, according to your 
Linux distribution (we assume that you already configured the 
`ntop repository <http://packages.ntop.org>`_ for installing *ntopng*).

*apt*

.. code:: bash

   apt-get install n2disk

*yum*

.. code:: bash

   yum install n2disk

In order to use *n2disk* a license is also required, you can get one at
`e-shop <http://shop.ntop.org>`_ or, if you are no-profit, research or an 
education institution please read `this <https://www.ntop.org/support/faq/do-you-charge-universities-no-profit-and-research/>`_.
The *n2disk* license can be installed directly from *ntopng* through the
*Preferences*, *Traffic Recording* menu. The same page also provides
the installed *n2disk* version and SystemID, both required to generate
the license.

.. figure:: ../img/web_gui_preferences_recording_license.png
  :align: center
  :alt: Traffic Recording License

  The Traffic Recording Preferences Page

At this point you are ready to start recording traffic. 
Packets are dumped to disk using the industry standard Pcap file format. The default 
folder for pcap files is the ntopng data directory, under the "pcap" folder of a 
specific network inteface id (e.g. `/var/lib/ntopng/0/pcap`), however it is possible to
replace the `/var/lib/ntopng` root folder with a different one adding *--pcap-dir <path>* 
to the *ntopng* configuration file.

In order to actually start recording traffic, you need to select an interface from 
the *Interfaces* menu, click on the disk icon, and configure the recording instance:

1. Select "Continuous Traffic Recording"
2. Configure the desired "Max Disk Space" value. This lets you control the maximum 
   disk space to be used for pcap files, which also affects the data retention time
   (when the maximum disk space is exceeded, the oldest pcap file is overwritten).
   Please note that the data retention time also depends on the traffic throughput 
   of the networks being monitored.
3. Press the "Save Settings" button to actually start recording.

.. figure:: ../img/web_gui_interfaces_recording.png
  :align: center
  :alt: Traffic Recording

  The Traffic Recording Page

At this point a new badge should appear on the right side of the footer. 
When the badge is blue, it means that traffic recording is running. Instead, when 
the badge is red, it means that there is a failure. 

.. figure:: ../img/web_gui_interfaces_recording_badge.png
  :align: center
  :scale: 50 %
  :alt: Traffic Recording Badge

  The Traffic Recording Bagde in the Footer

It is possible to get more information about the *n2disk* service status by 
clicking on the badge. The status page provides information including the uptime
of the recording service, statistics about processed traffic, the log trace.

.. figure:: ../img/web_gui_interfaces_recording_status.png
  :align: center
  :alt: Traffic Recording Status

  The Traffic Recording Status Page

Traffic Extraction
------------------

All pcap files dumped to disk are indexed on-the-fly by *n2disk* to improve traffic 
extraction speed when recorded data need to be retrieved.
It is possible to extract traffic from multiple places in *ntopng*, including the interface
and the host *Historical Traffic Statistics* pages. 

After enabling continuous traffic recording on an interface, a new *Extract pcap* button 
appears at the top right corner of the *Historical Traffic Statistics* page.

.. figure:: ../img/web_gui_interfaces_extract_pcap.png
  :align: center
  :alt: Extract pcap button

  The Extract Pcap Button in the Interface Historical Traffic Statistics page

.. figure:: ../img/web_gui_hosts_extract_pcap.png
  :align: center
  :alt: Extract pcap button

  The Extract Pcap Button in the Host Historical Traffic Statistics Page

By clicking on the button, a dialog box will let you run an extraction to retrieve the 
traffic matching the time interval selected on the chart.

.. figure:: ../img/web_gui_interfaces_extract_pcap_dialog.png
  :align: center
  :scale: 40 %
  :alt: Extract pcap dialog

  The Extract Pcap Dialog

In addition to the time constraint, it is possible to configure a BPF-like filter, 
to further reduce the extracted amount of data, by clicking on *Edit Filter*. The filter 
format is described at `Packet Filtering <https://www.ntop.org/guides/n2disk/filters.html>`_.

.. figure:: ../img/web_gui_interfaces_extract_pcap_dialog_filter.png
  :align: center
  :scale: 40 %
  :alt: Extract pcap dialog filter

  The Extract Pcap Dialog Filter

The *Extract pcap* button is also available in several other places while browsing the
historical data, an example is the list of the *Top Receivers* or *Top Senders* available 
at the bottom of the *Interface Historical Traffic Statistics* page. In this case, a button
on the left side of the row lets you download the traffic matching a specific host in the
selected time interval.

.. figure:: ../img/web_gui_interfaces_extract_pcap_from_list.png
  :align: center
  :alt: Extract pcap button

  The Extract Pcap Button in the Top Receivers in the Interface Historical Traffic Statistics Page

The dialog box in this case already contains a precomputed filter, that can be edited 
by clicking on *Edit Filter* to refine the extraction.

.. figure:: ../img/web_gui_interfaces_extract_pcap_dialog_filter_pre.png
  :align: center
  :scale: 40 %
  :alt: Extract pcap dialog filter

  The Extract Pcap Dialog Filter

The *Start Extraction* button will schedule the extraction, that will be processed in background.
It usually requires a few seconds, depending on a few factors, including: the time interval, the
amount of recorded data, the extraction filter. 

A reference for the extraction job (a link to the *Traffic Extraction Jobs* page with the list of 
scheduled extractions, and the extraction *ID*) is provided after starting the extraction, in order 
to control the status and download the pcap file(s) as soon as the extraction is completed.
Extraction jobs can be stopped anytime using the *Stop* button, in case of extractions taking too 
long, or removed using the *Delete* button (this will also delete the corresponding pcap files).

.. figure:: ../img/web_gui_interfaces_extraction_jobs.png
  :align: center
  :alt: Traffic Extraction Jobs

  The Traffic Extraction Jobs page

It is possible to access the *Traffic Extraction Jobs* page also by clicking on the badge that 
appears on the right side of the footer when there is at least one extraction job scheduled.

.. figure:: ../img/web_gui_interfaces_extraction_badge.png
  :align: center
  :scale: 50 %
  :alt: Traffic Extraction Jobs Badge

  The Traffic Extraction Jobs Bagde in the Footer


