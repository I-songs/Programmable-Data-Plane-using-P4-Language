/*
Copyright 2013-present Barefoot Networks, Inc. 

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include "includes/headers.p4"
#include "includes/parser.p4"

action _drop() {
    drop();
}

header_type routing_metadata_t {
    fields {
        nhop_ipv4 : 32;
    }
}

metadata routing_metadata_t routing_metadata;

action set_nhop(nhop_ipv4, port) {
    modify_field(routing_metadata.nhop_ipv4, nhop_ipv4);
    modify_field(standard_metadata.egress_spec, port);
    add_to_field(ipv4.ttl, -1);
}

table ipv4_lpm {
    reads {
        ipv4.dstAddr : lpm;
    }
    actions {
        set_nhop;
        _drop;
    }
    size: 1024;
}

action set_dmac(dmac) {
    modify_field(ethernet.dstAddr, dmac);
}

table forward {
    reads {
        routing_metadata.nhop_ipv4 : exact;
    }
    actions {
        set_dmac;
        _drop;
    }
    size: 512;
}

action rewrite_mac(smac) {
    modify_field(ethernet.srcAddr, smac);
}

table send_frame {
    reads {
        standard_metadata.egress_port: exact;
    }
    actions {
        rewrite_mac;
        _drop;
    }
    size : 256;
}

counter c_quic {
   type: packets_and_bytes;
   instance_count: 32;
}

action count_quic(){
   count(c_quic, 1);
}

table quic_count {
    reads { 
        udp.dstPort : exact;
    }
    actions { 
        count_quic; 
    }
    size : 256;
}

counter c_ssl {
   type: packets_and_bytes;
   instance_count: 32;
}

action count_ssl(){
   count(c_ssl, 1);
}

table ssl_count {
    reads { 
        udp.dstPort : exact;
    }
    actions { 
        count_ssl;
    }
    size: 256;
}

counter c_rtmp {
   type: packets_and_bytes;
   instance_count: 32;
}

action count_rtmp(){
   count(c_rtmp, 1);
}

table rtmp_count {
    reads { 
        tcp.dstPort : exact;
    }
    actions { 
        count_rtmp;
        _drop;
    }
    size : 256;
}

control ingress {
    /*apply(quic_count);
    apply(rtmp_count);
    apply(ssl_count);*/
    apply(ipv4_lpm);
    apply(forward);
}

control egress {
    apply(send_frame);
}


