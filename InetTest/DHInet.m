//
//  DHInet.m
//  InetTest
//
//  Created by Daniel Nestor Corbatta Barreto on 20/11/13.
//  Copyright (c) 2013 Daniel Nestor Corbatta Barreto. All rights reserved.
//

#import "DHInet.h"
#import "privateheader.h"

@implementation DHInet

#define  SO_TC_MAX	10
char *
inetname(struct in_addr *inp)
{
	register char *cp;
	static char line[MAXHOSTNAMELEN];
	struct hostent *hp;
	struct netent *np;
    
	cp = 0;
	if (!nflag && inp->s_addr != INADDR_ANY) {
		int net = inet_netof(*inp);
		int lna = inet_lnaof(*inp);
        
		if (lna == INADDR_ANY) {
			np = getnetbyaddr(net, AF_INET);
			if (np)
				cp = np->n_name;
		}
		if (cp == 0) {
			hp = gethostbyaddr((char *)inp, sizeof (*inp), AF_INET);
			if (hp) {
				cp = hp->h_name;
                //### trimdomain(cp, strlen(cp));
			}
		}
	}
	if (inp->s_addr == INADDR_ANY)
		strlcpy(line, "*", sizeof(line));
	else if (cp) {
		strncpy(line, cp, sizeof(line) - 1);
		line[sizeof(line) - 1] = '\0';
	} else {
		inp->s_addr = ntohl(inp->s_addr);
#define C(x)	((u_int)((x) & 0xff))
		snprintf(line, sizeof(line), "%u.%u.%u.%u", C(inp->s_addr >> 24),
                 C(inp->s_addr >> 16), C(inp->s_addr >> 8), C(inp->s_addr));
	}
	return (line);
}

void
inetprint(struct in_addr *in, int port, const char *proto, int numeric_port, NSDictionary * conect, NSString * address)
{
	struct servent *sp = 0;
	char line[80], *cp;
	int width;
    
	if (Wflag)
	    snprintf(line, sizeof(line), "%s.", inetname(in));
	else
	    snprintf(line, sizeof(line), "%.*s.", (Aflag && !numeric_port) ? 12 : 16, inetname(in));
	cp = index(line, '\0');
	if (!numeric_port && port)
#ifdef _SERVICE_CACHE_
		sp = _serv_cache_getservbyport(port, proto);
#else
    sp = getservbyport((int)port, proto);
#endif
	if (sp || port == 0)
		snprintf(cp, sizeof(line) - (cp - line), "%.15s ", sp ? sp->s_name : "*");
	else
		snprintf(cp, sizeof(line) - (cp - line), "%d ", ntohs((u_short)port));
	width = (Aflag && !Wflag) ? 18 : 22;
	if (Wflag)
	    printf("%-*s ", width, line);
	else
	    printf("%-*.*s ", width, width, line);
    
    [conect setValue:[NSString stringWithUTF8String:line ] forKey:address];
}

- (NSArray *) protopr:(uint32_t) proto name:(const char *) name af:(int) af{
    NSMutableArray * tcpConnectionsActive = [NSMutableArray array];
    
    int istcp;
    static int first = 1;
    char *buf;
    const char *mibvar;
    struct xinpgen *xig, *oxig;
#if !TARGET_OS_EMBEDDED
    struct xtcpcb64 *tp = NULL;
    struct xinpcb64 *inp;
    struct xsocket64 *so;
#else
    struct tcpcb *tp = NULL;
    struct inpcb *inp;
    struct xsocket *so;
#endif
    size_t len;
    
    istcp = 0;
    switch (proto) {
        case IPPROTO_TCP:
#ifdef INET6
            if (tcp_done != 0)
                return;
            else
                tcp_done = 1;
#endif
            istcp = 1;
#if !TARGET_OS_EMBEDDED
            mibvar = "net.inet.tcp.pcblist64";
#else
            mibvar = "net.inet.tcp.pcblist";
#endif
            break;
        case IPPROTO_UDP:
#ifdef INET6
            if (udp_done != 0)
                return;
            else
                udp_done = 1;
#endif
#if !TARGET_OS_EMBEDDED
            mibvar = "net.inet.udp.pcblist64";
#else
            mibvar = "net.inet.udp.pcblist";
#endif
            break;
        case IPPROTO_DIVERT:
#if !TARGET_OS_EMBEDDED
            mibvar = "net.inet.divert.pcblist64";
#else
            mibvar = "net.inet.divert.pcblist";
#endif
            break;
        default:
#if !TARGET_OS_EMBEDDED
            mibvar = "net.inet.raw.pcblist64";
#else
            mibvar = "net.inet.raw.pcblist";
#endif
            break;
    }
    len = 0;
    if (sysctlbyname(mibvar, 0, &len, 0, 0) < 0) {
        if (errno != ENOENT)
            warn("sysctl: %s", mibvar);
        return nil;
    }
    if ((buf = malloc(len)) == 0) {
        warn("malloc %lu bytes", (u_long)len);
        return nil;
    }
    if (sysctlbyname(mibvar, buf, &len, 0, 0) < 0) {
        warn("sysctl: %s", mibvar);
        free(buf);
        return nil;
    }
    
    /*
     * Bail-out to avoid logic error in the loop below when
     * there is in fact no more control block to process
     */
    if (len <= sizeof(struct xinpgen)) {
        free(buf);
        return nil;
    }
    
    oxig = xig = (struct xinpgen *)buf;
    for (xig = (struct xinpgen *)((char *)xig + xig->xig_len);
         xig->xig_len > sizeof(struct xinpgen);
         xig = (struct xinpgen *)((char *)xig + xig->xig_len)) {
        if (istcp) {
#if !TARGET_OS_EMBEDDED
            tp = (struct xtcpcb64 *)xig;
            inp = &tp->xt_inpcb;
            so = &inp->xi_socket;
#else
            tp = &((struct xtcpcb *)xig)->xt_tp;
            inp = &((struct xtcpcb *)xig)->xt_inp;
            so = &((struct xtcpcb *)xig)->xt_socket;
#endif
        } else {
#if !TARGET_OS_EMBEDDED
            inp = (struct xinpcb64 *)xig;
            so = &inp->xi_socket;
#else
            inp = &((struct xinpcb *)xig)->xi_inp;
            so = &((struct xinpcb *)xig)->xi_socket;
#endif
        }
        
        /* Ignore sockets for protocols other than the desired one. */
        if (so->xso_protocol != (int)proto)
            continue;
        
        /* Ignore PCBs which were freed during copyout. */
        if (inp->inp_gencnt > oxig->xig_gen)
            continue;
        
        if ((af == AF_INET && (inp->inp_vflag & INP_IPV4) == 0)
#ifdef INET6
            || (af == AF_INET6 && (inp->inp_vflag & INP_IPV6) == 0)
#endif /* INET6 */
            || (af == AF_UNSPEC && ((inp->inp_vflag & INP_IPV4) == 0
#ifdef INET6
                                    && (inp->inp_vflag &
                                        INP_IPV6) == 0
#endif /* INET6 */
                                    ))
            )
            continue;
        
        /*
         * Local address is not an indication of listening socket or
         * server sockey but just rather the socket has been bound.
         * That why many UDP sockets were not displayed in the original code.
         */
        if (!aflag && istcp && tp->t_state <= TCPS_LISTEN)
            continue;
        
        if (Lflag && !so->so_qlimit)
            continue;
        
        if (first) {
            if (!Lflag) {
                printf("Active Internet connections");
                if (aflag)
                    printf(" (including servers)");
            } else
                printf(
                       "Current listen queue sizes (qlen/incqlen/maxqlen)");
            putchar('\n');
            if (Aflag)
#if !TARGET_OS_EMBEDDED
                printf("%-16.16s ", "Socket");
#else
            printf("%-8.8s ", "Socket");
#endif
            if (Lflag)
                printf("%-14.14s %-22.22s\n",
                       "Listen", "Local Address");
            else
                printf((Aflag && !Wflag) ?
                       "%-5.5s %-6.6s %-6.6s  %-18.18s %-18.18s %s\n" :
                       "%-5.5s %-6.6s %-6.6s  %-22.22s %-22.22s %s\n",
                       "Proto", "Recv-Q", "Send-Q",
                       "Local Address", "Foreign Address",
                       "(state)");
            first = 0;
        }
        NSMutableDictionary * conection = [NSMutableDictionary dictionary];
        if (Aflag) {
            if (istcp)
#if !TARGET_OS_EMBEDDED
                printf("%16lx ", (u_long)inp->inp_ppcb);
#else
            printf("%8lx ", (u_long)inp->inp_ppcb);
            
#endif
            else
#if !TARGET_OS_EMBEDDED
                printf("%16lx ", (u_long)so->so_pcb);
#else
            printf("%8lx ", (u_long)so->so_pcb);
#endif
        }
        if (Lflag) {
            char buf[15];
            
            snprintf(buf, 15, "%d/%d/%d", so->so_qlen,
                     so->so_incqlen, so->so_qlimit);
            printf("%-14.14s ", buf);
        }
        else {
            const char *vchar;
            
#ifdef INET6
            if ((inp->inp_vflag & INP_IPV6) != 0)
                vchar = ((inp->inp_vflag & INP_IPV4) != 0)
                ? "46" : "6 ";
            else
#endif
                vchar = ((inp->inp_vflag & INP_IPV4) != 0)
                ? "4 " : "  ";
            char protoname [50];
            snprintf ( protoname, 50, "%-3.3s%-2.2s", name, vchar );
            
            [conection setObject:[NSString stringWithUTF8String:protoname ] forKey:@"Proto"];
//            [conection setObject:[NSNumber numberWithInt:so_rcv->sb_cc] forKey:@"Recv-Q" ];
//            [conection setObject:[NSNumber numberWithInt:so_snd->sb_cc] forKey:@"Send-Q" ];
            printf("%-3.3s%-2.2s %6u %6u  ", name, vchar,
                   so->so_rcv.sb_cc,
                   so->so_snd.sb_cc);
        }
        if (nflag) {
            if (inp->inp_vflag & INP_IPV4) {
                inetprint(&inp->inp_laddr, (int)inp->inp_lport,
                          name, 1,conection,@"Local Address");
                if (!Lflag)
                    inetprint(&inp->inp_faddr,
                              (int)inp->inp_fport, name, 1,conection,@"Foreign Address");
            }
#ifdef INET6
            else if (inp->inp_vflag & INP_IPV6) {
                inet6print(&inp->in6p_laddr,
                           (int)inp->inp_lport, name, 1);
                if (!Lflag)
                    inet6print(&inp->in6p_faddr,
                               (int)inp->inp_fport, name, 1);
            } /* else nothing printed now */
#endif /* INET6 */
        } else if (inp->inp_flags & INP_ANONPORT) {
            if (inp->inp_vflag & INP_IPV4) {
                inetprint(&inp->inp_laddr, (int)inp->inp_lport,
                          name, 1,conection,@"Foreign Address");
                if (!Lflag)
                    inetprint(&inp->inp_faddr,
                              (int)inp->inp_fport, name, 0,conection,@"Foreign Address");
            }
#ifdef INET6
            else if (inp->inp_vflag & INP_IPV6) {
                inet6print(&inp->in6p_laddr,
                           (int)inp->inp_lport, name, 1);
                if (!Lflag)
                    inet6print(&inp->in6p_faddr,
                               (int)inp->inp_fport, name, 0);
            } /* else nothing printed now */
#endif /* INET6 */
        } else {
            if (inp->inp_vflag & INP_IPV4) {
                inetprint(&inp->inp_laddr, (int)inp->inp_lport,
                          name, 0, conection,@"Local Address");
                if (!Lflag)
                    inetprint(&inp->inp_faddr,
                              (int)inp->inp_fport, name,
                              inp->inp_lport !=
                              inp->inp_fport,conection,@"Foreign Address");
            }
#ifdef INET6
            else if (inp->inp_vflag & INP_IPV6) {
                inet6print(&inp->in6p_laddr,
                           (int)inp->inp_lport, name, 0);
                if (!Lflag)
                    inet6print(&inp->in6p_faddr,
                               (int)inp->inp_fport, name,
                               inp->inp_lport !=
                               inp->inp_fport);
            } /* else nothing printed now */
#endif /* INET6 */
        }
        if (istcp && !Lflag) {
            if (tp->t_state < 0 || tp->t_state >= TCP_NSTATES)
                printf("%d", tp->t_state);
            [conection setValue:[NSString stringWithUTF8String:tcpstates[tp->t_state]] forKey:@"State"];
        }
            else {
                printf("%s", tcpstates[tp->t_state]);
                [conection setValue:[NSString stringWithUTF8String:tcpstates[tp->t_state]] forKey:@"State"];
#if defined(TF_NEEDSYN) && defined(TF_NEEDFIN)
                /* Show T/TCP `hidden state' */
                if (tp->t_flags & (TF_NEEDSYN|TF_NEEDFIN))
                    putchar('*');
#endif /* defined(TF_NEEDSYN) && defined(TF_NEEDFIN) */
            }
        putchar('\n');
        [tcpConnectionsActive addObject:conection];
    }
    if (xig != oxig && xig->xig_gen != oxig->xig_gen) {
        if (oxig->xig_count > xig->xig_count) {
            printf("Some %s sockets may have been deleted.\n",
                   name);
        } else if (oxig->xig_count < xig->xig_count) {
            printf("Some %s sockets may have been created.\n",
                   name);
        } else {
            printf("Some %s sockets may have been created or deleted",
                   name);
        }
    }
    free(buf);
    return tcpConnectionsActive;
}
// You can change this flag to change the info showed.

int	Aflag = 0;	/* show addresses of protocol control block */
int	aflag = 0;	/* show all sockets (including servers) */
int	bflag = 1;	/* show i/f total bytes in/out */
int	Lflag = 0;	/* show size of listen queues */
int	Wflag = 0;	/* wide display */
int	prioflag = 0; /* show packet priority  statistics */
int	sflag = 0;	/* show protocol statistics */
int	nflag = 0;	/* show addresses numerically */
int	interval = 1; /* repeat interval for i/f stats */

- (NSArray *) getTCPConnections{
    return [self protopr:IPPROTO_TCP name:"tcp" af:AF_INET];
}
- (NSArray *) getUDPConnections{
    return [self protopr:IPPROTO_UDP name:"udp" af:AF_INET];
}
@end
