#!/usr/bin/env python

from jinja2 import Environment
import sys
import yaml
import base64
import libvirt
import subprocess

tmpl_type = 'default'

if len(sys.argv) <= 1:
    print("Usage: <script> <vm_name>")

vm_name = sys.argv[1]

size_gb = 0
arch = 'amd64' # | 'arm64'
efipart = 1
rootpart = 2

if len(sys.argv) > 2:
    tmpl_type = sys.argv[2]

print("Generating Init Script")

tmpl = open("init-%s.sh.tmpl" % tmpl_type).read()
values = yaml.load(open("values-%s.yml" % vm_name).read())

if 'host' not in values:
    values['host'] = vm_name

if 'rootGB' in values:
    size_gb = values['rootGB']

if 'arch' in values:
    arch = values['arch']

if arch == 'arm64':
    efipart = 15
    rootpart = 1

txt = Environment().from_string(tmpl).render(**values)

encoded_txt = base64.b64encode(txt)

chunk_size = 1023 # max b64-encoded characters you can pass per chunk

chunks = [encoded_txt[i:i+chunk_size] for i in range(0, len(encoded_txt), chunk_size)]

if len(chunks) > 1:
    # since the guest only reads the first oemtable if we have more 
    # we need to build an index in the first table to read the others
    first_table_txt = """#!/bin/bash\nfor t in {2..%s}; do dmidecode --oem-string $t; done | tr -d '\\n' | base64 -d -w0 | bash""" % str(len(chunks) + 1)
    chunks = [base64.b64encode(first_table_txt)] + chunks

print("Generating Guest XML")

guest_tmpl = open("libvirt_guest_%s.xml.tmpl" % arch).read()


guest_txt = Environment().from_string(guest_tmpl).render(**locals())

print("Connecting to Libvirt")
conn = libvirt.open()

print("Cloning the Base Image")
pool = conn.storagePoolLookupByName("libvirt-pool")
base_volume = pool.storageVolLookupByName("debcore_guest_latest_%s" % arch)
newvol_xml = """
<volume type='block'>
  <name>%s</name>
  <capacity unit="G">%s</capacity>
  <target>
    <path>/dev/libvirt_pool/%s</path>
  </target>
</volume>
""" % (vm_name,str(size_gb),vm_name)

newvol = pool.createXMLFrom(newvol_xml, base_volume, 0)

if size_gb > 0 and arch == 'amd64':
  print("Resizing Volume with libGuestFS")
  subprocess.call(['/usr/bin/virt-resize', '--expand', '/dev/vda%s' % rootpart, '/dev/libvirt_pool/debcore_guest_latest_%s' % arch, '/dev/libvirt_pool/%s' % vm_name ])

print("Defining the Guest in Libvirt")
dom = conn.defineXML(guest_txt)

print("Starting the Guest")
dom.create()
dom.setAutostart(1)

print("Done.")
